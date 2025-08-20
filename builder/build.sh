#!/bin/bash
################################################################################
### OpenWRT Custom Builder - Main Build Script
### BPI-R4 Debian/OpenWRT Hybrid Image Builder
################################################################################
### Project: OpenWRT Custom Builder
### Version: 1.0.0
### Author:  Mawage (OpenWRT Builder Team)
### Date:    2025-08-19
### License: MIT
################################################################################

set -e

################################################################################
### INITIALIZATION
################################################################################

### Script directory and paths ###
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

### Load helper functions ###
if [ -f "$SCRIPT_DIR/helper.sh" ]; then
    source "$SCRIPT_DIR/helper.sh"
else
    echo "ERROR: Helper functions not found at $SCRIPT_DIR/helper.sh"
    exit 1
fi

### Load configurations ###
load_config "$SCRIPT_DIR/config/builder.cfg" false
load_config "$PROJECT_ROOT/config/global.cfg" false

################################################################################
### DEFAULT CONFIGURATION
################################################################################

### Build Configuration ###
BUILD_TYPE="${BUILD_TYPE:-debian-luci}"
TARGET_DEVICE="${TARGET_DEVICE:-bpi-r4}"
IMAGE_SIZE="${IMAGE_SIZE:-8G}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"
WORK_DIR="${WORK_DIR:-$SCRIPT_DIR/work}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/log}"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/cache}"

### System Configuration ###
DEBIAN_VERSION="${DEBIAN_VERSION:-bookworm}"
KERNEL_VERSION="${KERNEL_VERSION:-6.6}"
HOSTNAME="${HOSTNAME:-bpi-r4}"
ROOT_PASSWORD="${ROOT_PASSWORD:-bananapi}"
LAN_IP="${LAN_IP:-192.168.1.1}"
LAN_NETMASK="${LAN_NETMASK:-255.255.255.0}"

### Build Options ###
ENABLE_LUCI="${ENABLE_LUCI:-true}"
ENABLE_DOCKER="${ENABLE_DOCKER:-false}"
ENABLE_WIFI="${ENABLE_WIFI:-true}"
COMPRESS_IMAGE="${COMPRESS_IMAGE:-true}"
PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc)}"

### Initialize with logging ###
LOG_FILE="$LOG_DIR/build_$(get_timestamp).log"
init_helpers "build.sh" "$LOG_FILE"

################################################################################
### BUILD FUNCTIONS
################################################################################

### Setup directories ###
setup_directories() {
    print_step "1" "Setting up directory structure"
    
    local dirs=(
        "$OUTPUT_DIR"
        "$WORK_DIR"
        "$LOG_DIR"
        "$CACHE_DIR"
        "$SCRIPT_DIR/scripts"
        "$SCRIPT_DIR/boot"
        "$SCRIPT_DIR/config"
    )
    
    for dir in "${dirs[@]}"; do
        validate_directory "$dir" true
        print_check "Created: $dir"
    done
}

### Check system requirements ###
check_requirements() {
    print_step "2" "Checking system requirements"
    
    local required_commands=(
        "debootstrap:debootstrap"
        "parted:parted"
        "mkfs.ext4:e2fsprogs"
        "mkfs.vfat:dosfstools"
        "rsync:rsync"
        "wget:wget"
        "git:git"
        "xz:xz-utils"
    )
    
    local missing_packages=()
    
    for item in "${required_commands[@]}"; do
        local cmd="${item%:*}"
        local package="${item#*:}"
        
        if command -v "$cmd" >/dev/null 2>&1; then
            print_check "Found: $cmd"
        else
            print_cross "Missing: $cmd"
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_warning "Installing missing dependencies..."
        apt-get update >> "$LOG_FILE" 2>&1
        apt-get install -y "${missing_packages[@]}" >> "$LOG_FILE" 2>&1 || \
            error_exit "Failed to install dependencies"
        print_success "Dependencies installed successfully"
    fi
}

### Display build configuration ###
show_config() {
    print_header "BUILD CONFIGURATION"
    
    print_box "Build Settings" \
        "Build Type:      $BUILD_TYPE
Target Device:   $TARGET_DEVICE
Image Size:      $IMAGE_SIZE
Output Dir:      $OUTPUT_DIR"
    
    print_box "System Settings" \
        "Debian Version:  $DEBIAN_VERSION
Kernel Version:  $KERNEL_VERSION
Hostname:        $HOSTNAME
LAN IP:          $LAN_IP"
    
    print_box "Build Options" \
        "Enable LuCI:     $ENABLE_LUCI
Enable Docker:   $ENABLE_DOCKER
Enable WiFi:     $ENABLE_WIFI
Compress Image:  $COMPRESS_IMAGE
Parallel Jobs:   $PARALLEL_JOBS"
}

### Ask for confirmation ###
confirm_build() {
    print_warning "This will create a new system image."
    echo ""
    
    if ! ask_yes_no "Do you want to continue?" "no"; then
        print_info "Build cancelled by user."
        exit 0
    fi
}

### Execute build script based on type ###
execute_build() {
    print_header "EXECUTING BUILD"
    
    local build_script=""
    
    case "$BUILD_TYPE" in
        "debian-luci")
            build_script="$SCRIPT_DIR/scripts/debian-luci.sh"
            ;;
        "openwrt")
            build_script="$SCRIPT_DIR/scripts/openwrt.sh"
            ;;
        "debian-minimal")
            build_script="$SCRIPT_DIR/scripts/debian-minimal.sh"
            ;;
        *)
            error_exit "Unknown build type: $BUILD_TYPE"
            ;;
    esac
    
    validate_file "$build_script"
    
    print_info "Executing: $build_script"
    
    ### Export variables for build script ###
    export OUTPUT_DIR WORK_DIR LOG_DIR CACHE_DIR
    export DEBIAN_VERSION KERNEL_VERSION HOSTNAME ROOT_PASSWORD
    export LAN_IP LAN_NETMASK IMAGE_SIZE
    export ENABLE_LUCI ENABLE_DOCKER ENABLE_WIFI
    export COMPRESS_IMAGE PARALLEL_JOBS
    export TARGET_DEVICE
    
    ### Execute build script ###
    local start_time=$SECONDS
    
    if bash "$build_script"; then
        local duration=$((SECONDS - start_time))
        print_success "Build completed successfully in $(format_duration $duration)!"
        return 0
    else
        error_exit "Build failed! Check log: $LOG_FILE"
    fi
}

### Post-build actions ###
post_build() {
    print_header "POST-BUILD ACTIONS"
    
    ### List created images ###
    print_subheader "Created Images"
    if ls "$OUTPUT_DIR"/*.img* >/dev/null 2>&1; then
        ls -lh "$OUTPUT_DIR"/*.img*
        print_success "Images created successfully"
    else
        print_warning "No images found in output directory"
    fi
    
    ### Check for SD card writer script ###
    if [ -f "$SCRIPT_DIR/scripts/write-media.sh" ]; then
        print_info "To write the image to SD card, run:"
        print_bullet 0 "sudo $SCRIPT_DIR/scripts/write-media.sh"
    fi
    
    ### Generate summary ###
    generate_summary
}

### Generate build summary ###
generate_summary() {
    local summary_file="$OUTPUT_DIR/build_summary_$(get_timestamp).txt"
    
    {
        echo "################################################################################"
        echo "### BUILD SUMMARY"
        echo "################################################################################"
        echo "Date:           $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Build Type:     $BUILD_TYPE"
        echo "Target Device:  $TARGET_DEVICE"
        echo "Image Size:     $IMAGE_SIZE"
        echo "Debian Version: $DEBIAN_VERSION"
        echo "Kernel Version: $KERNEL_VERSION"
        echo "Hostname:       $HOSTNAME"
        echo "LAN IP:         $LAN_IP"
        echo ""
        echo "Output Files:"
        ls -lh "$OUTPUT_DIR"/*.img* 2>/dev/null || echo "  No images found"
        echo ""
        echo "Next Steps:"
        echo "  1. Check output in: $OUTPUT_DIR"
        echo "  2. Write to SD card: sudo $SCRIPT_DIR/scripts/write-media.sh"
        echo "  3. Boot your $TARGET_DEVICE"
        echo "################################################################################"
    } > "$summary_file"
    
    print_success "Build summary saved to: $summary_file"
}

### Cleanup function ###
cleanup() {
    print_info "Cleaning up..."
    
    ### Unmount any mounted filesystems ###
    for mount in $(mount | grep "$WORK_DIR" | awk '{print $3}' | sort -r); do
        safe_unmount "$mount"
    done
    
    ### Remove loop devices ###
    cleanup_loop_devices "$WORK_DIR"
    
    print_success "Cleanup completed"
}

################################################################################
### COMMAND LINE INTERFACE
################################################################################

### Show usage information ###
show_usage() {
    cat << EOF
################################################################################
### OpenWRT Custom Builder v1.0.0
################################################################################

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -t, --type TYPE         Build type (debian-luci, openwrt, debian-minimal)
    -d, --device DEVICE     Target device (bpi-r4)
    -s, --size SIZE         Image size (default: 8G)
    -o, --output DIR        Output directory
    -j, --jobs N            Parallel jobs (default: $(nproc))
    -q, --quiet             Quiet mode
    -v, --verbose           Verbose mode
    --no-compress           Don't compress final image
    --enable-docker         Enable Docker support
    --disable-luci          Disable LuCI web interface
    --hostname NAME         Set hostname (default: bpi-r4)
    --lan-ip IP             Set LAN IP (default: 192.168.1.1)

EXAMPLES:
    $0                                      # Default build
    $0 -t debian-luci -d bpi-r4            # Debian with LuCI
    $0 --type openwrt --enable-docker      # OpenWrt with Docker
    $0 -q -j 8 --no-compress              # Quiet, 8 jobs, no compression

AVAILABLE BUILD TYPES:
    debian-luci       Debian 12 with OpenWrt LuCI interface
    debian-minimal    Minimal Debian 12 system
    openwrt           Pure OpenWrt system

EOF
}

### Parse command line arguments ###
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -t|--type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            -d|--device)
                TARGET_DEVICE="$2"
                shift 2
                ;;
            -s|--size)
                IMAGE_SIZE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -q|--quiet)
                DEFAULT_QUIET_MODE=true
                shift
                ;;
            -v|--verbose)
                DEFAULT_VERBOSE_MODE=true
                shift
                ;;
            --no-compress)
                COMPRESS_IMAGE=false
                shift
                ;;
            --enable-docker)
                ENABLE_DOCKER=true
                shift
                ;;
            --disable-luci)
                ENABLE_LUCI=false
                shift
                ;;
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --lan-ip)
                LAN_IP="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

################################################################################
### MAIN EXECUTION
################################################################################

### Main function ###
main() {
    ### Parse arguments ###
    parse_arguments "$@"
    
    ### Show header ###
    print_header "OpenWRT CUSTOM BUILDER v1.0.0"
    
    ### Check if running as root ###
    check_root
    
    ### Setup directories ###
    setup_directories
    
    ### Check system requirements ###
    check_requirements
    
    ### Check disk space ###
    check_disk_space "$WORK_DIR" 20
    
    ### Show configuration ###
    show_config
    
    ### Ask for confirmation ###
    confirm_build
    
    ### Execute build ###
    local total_start_time=$SECONDS
    execute_build
    
    ### Post-build actions ###
    post_build
    
    ### Final success message ###
    local total_duration=$((SECONDS - total_start_time))
    
    print_header "BUILD COMPLETED SUCCESSFULLY"
    
    print_success "Total build time: $(format_duration $total_duration)"
    print_success "Log file: $LOG_FILE"
    echo ""
    print_info "Next steps:"
    print_bullet 0 "Check output in: $OUTPUT_DIR"
    print_bullet 0 "Write to SD card: sudo $SCRIPT_DIR/scripts/write-media.sh"
    print_bullet 0 "Boot your $TARGET_DEVICE"
    
    exit 0
}

### Run main function ###
main "$@"