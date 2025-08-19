#!/bin/bash
################################################################################
### OpenWRT Custom Builder - Main Build Script
### BPI-R4 Debian/OpenWRT Hybrid Image Builder
################################################################################
### Project: OpenWRT Custom Builder
### Version: 1.0.0
### Author:  OpenWRT Builder Team
### Date:    2025-08-19
### License: MIT
################################################################################

################################################################################
### CONFIGURATION SECTION
################################################################################

### Script directory and paths ###
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

### Load builder configuration ###
BUILDER_CONFIG="$SCRIPT_DIR/config/builder.cfg"
if [ -f "$BUILDER_CONFIG" ]; then
    source "$BUILDER_CONFIG"
else
    echo "⚠️  Warning: Builder configuration not found at $BUILDER_CONFIG"
    echo "   Creating default configuration..."
    mkdir -p "$SCRIPT_DIR/config"
    cat > "$BUILDER_CONFIG" << 'EOF'

################################################################################
### Builder Configuration
################################################################################

### Path Configuration ###
OUTPUT_DIR="$SCRIPT_DIR/output"
WORK_DIR="$SCRIPT_DIR/work"
LOG_DIR="$SCRIPT_DIR/log"
CACHE_DIR="$SCRIPT_DIR/cache"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
BOOT_DIR="$SCRIPT_DIR/boot"

### Build Defaults ###
DEFAULT_BUILD_TYPE="debian-luci"
DEFAULT_TARGET_DEVICE="bpi-r4"
DEFAULT_IMAGE_SIZE="8G"
DEFAULT_COMPRESS="true"
EOF
    source "$BUILDER_CONFIG"
fi

### Create symbolic link to global config if not exists ###
if [ ! -L "$SCRIPT_DIR/config/global.cfg" ]; then
    ln -sf "$PROJECT_ROOT/config/global.cfg" "$SCRIPT_DIR/config/global.cfg" 2>/dev/null
fi

### Load global configuration ###
GLOBAL_CONFIG="$PROJECT_ROOT/config/global.cfg"
if [ -f "$GLOBAL_CONFIG" ]; then
    source "$GLOBAL_CONFIG"
else
    echo "⚠️  Warning: Global configuration file not found at $GLOBAL_CONFIG"
    echo "   Using default values..."
fi

################################################################################
### DEFAULT CONFIGURATION (if configs not found)
################################################################################

### Build Configuration ###
BUILD_TYPE="${BUILD_TYPE:-$DEFAULT_BUILD_TYPE}"
TARGET_DEVICE="${TARGET_DEVICE:-$DEFAULT_TARGET_DEVICE}"
IMAGE_SIZE="${IMAGE_SIZE:-$DEFAULT_IMAGE_SIZE}"
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
COMPRESS_IMAGE="${COMPRESS_IMAGE:-$DEFAULT_COMPRESS}"
PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc)}"

### Colors for output ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' ### No Color ###

################################################################################
### HELPER FUNCTIONS
################################################################################

### Print colored message ###
print_msg() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

### Print section header ###
print_header() {
    echo ""
    echo -e "${BLUE}################################################################################${NC}"
    echo -e "${BLUE}### $1${NC}"
    echo -e "${BLUE}################################################################################${NC}"
    echo ""
}

### Print sub-header ###
print_subheader() {
    echo ""
    echo -e "${CYAN}-----------------------------------------------------------------------------${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}-----------------------------------------------------------------------------${NC}"
}

### Error handling ###
error_exit() {
    print_msg "$RED" "❌ ERROR: $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    exit 1
}

### Check if running as root ###
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (sudo)"
    fi
}

### Create directory structure ###
setup_directories() {
    print_subheader "Setting up directory structure"
    
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
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_msg "$GREEN" "  ✓ Created: $dir"
        else
            print_msg "$WHITE" "  • Exists: $dir"
        fi
    done
}

### Setup logging ###
setup_logging() {
    LOG_FILE="$LOG_DIR/build_$(date '+%Y%m%d_%H%M%S').log"
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    echo "################################################################################" >> "$LOG_FILE"
    echo "### Build started at: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "### Build type: $BUILD_TYPE" >> "$LOG_FILE"
    echo "### Target device: $TARGET_DEVICE" >> "$LOG_FILE"
    echo "################################################################################" >> "$LOG_FILE"
    
    print_msg "$GREEN" "  ✓ Logging to: $LOG_FILE"
}

### Check system requirements ###
check_requirements() {
    print_subheader "Checking system requirements"
    
    local required_commands=(
        "debootstrap"
        "parted"
        "mkfs.ext4"
        "mkfs.vfat"
        "rsync"
        "wget"
        "git"
        "xz"
    )
    
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
            print_msg "$RED" "  ✗ Missing: $cmd"
        else
            print_msg "$GREEN" "  ✓ Found: $cmd"
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_msg "$YELLOW" ""
        print_msg "$YELLOW" "Installing missing dependencies..."
        apt-get update
        apt-get install -y debootstrap parted dosfstools e2fsprogs \
                          rsync wget git xz-utils qemu-user-static \
                          device-tree-compiler u-boot-tools || \
            error_exit "Failed to install dependencies"
    fi
}

### Display build configuration ###
show_config() {
    print_header "BUILD CONFIGURATION"
    
    print_msg "$WHITE" "  Build Settings:"
    print_msg "$CYAN" "    • Build Type:      $BUILD_TYPE"
    print_msg "$CYAN" "    • Target Device:   $TARGET_DEVICE"
    print_msg "$CYAN" "    • Image Size:      $IMAGE_SIZE"
    print_msg "$CYAN" "    • Output Dir:      $OUTPUT_DIR"
    
    print_msg "$WHITE" ""
    print_msg "$WHITE" "  System Settings:"
    print_msg "$CYAN" "    • Debian Version:  $DEBIAN_VERSION"
    print_msg "$CYAN" "    • Kernel Version:  $KERNEL_VERSION"
    print_msg "$CYAN" "    • Hostname:        $HOSTNAME"
    print_msg "$CYAN" "    • LAN IP:          $LAN_IP"
    
    print_msg "$WHITE" ""
    print_msg "$WHITE" "  Build Options:"
    print_msg "$CYAN" "    • Enable LuCI:     $ENABLE_LUCI"
    print_msg "$CYAN" "    • Enable Docker:   $ENABLE_DOCKER"
    print_msg "$CYAN" "    • Enable WiFi:     $ENABLE_WIFI"
    print_msg "$CYAN" "    • Compress Image:  $COMPRESS_IMAGE"
    print_msg "$CYAN" "    • Parallel Jobs:   $PARALLEL_JOBS"
}

### Ask for confirmation ###
confirm_build() {
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "⚠️  This will create a new system image."
    print_msg "$WHITE" ""
    read -p "Do you want to continue? (yes/no): " -r response
    
    if [[ ! "$response" =~ ^[Yy]es$ ]]; then
        print_msg "$RED" "Build cancelled by user."
        exit 0
    fi
}

################################################################################
### BUILD FUNCTIONS
################################################################################

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
    
    if [ ! -f "$build_script" ]; then
        error_exit "Build script not found: $build_script"
    fi
    
    print_msg "$CYAN" "  Executing: $build_script"
    
    ### Export variables for build script ###
    export OUTPUT_DIR WORK_DIR LOG_DIR CACHE_DIR
    export DEBIAN_VERSION KERNEL_VERSION HOSTNAME ROOT_PASSWORD
    export LAN_IP LAN_NETMASK IMAGE_SIZE
    export ENABLE_LUCI ENABLE_DOCKER ENABLE_WIFI
    export COMPRESS_IMAGE PARALLEL_JOBS
    export TARGET_DEVICE
    
    ### Execute build script ###
    if bash "$build_script"; then
        print_msg "$GREEN" "  ✓ Build completed successfully!"
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
    if [ -d "$OUTPUT_DIR" ]; then
        ls -lh "$OUTPUT_DIR"/*.img* 2>/dev/null || print_msg "$YELLOW" "  No images found"
    fi
    
    ### Check for SD card writer script ###
    if [ -f "$SCRIPT_DIR/scripts/write-sd.sh" ]; then
        print_msg "$WHITE" ""
        print_msg "$WHITE" "To write the image to SD card, run:"
        print_msg "$CYAN" "  sudo $SCRIPT_DIR/scripts/write-sd.sh"
    fi
    
    ### Generate summary ###
    generate_summary
}

### Generate build summary ###
generate_summary() {
    local summary_file="$OUTPUT_DIR/build_summary.txt"
    
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
        echo "################################################################################"
    } > "$summary_file"
    
    print_msg "$GREEN" ""
    print_msg "$GREEN" "  ✓ Build summary saved to: $summary_file"
}

### Cleanup on exit ###
cleanup() {
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "Cleaning up..."
    
    ### Unmount any mounted filesystems ###
    for mount in $(mount | grep "$WORK_DIR" | awk '{print $3}'); do
        umount "$mount" 2>/dev/null
    done
    
    ### Remove loop devices ###
    for loop in $(losetup -a | grep "$WORK_DIR" | cut -d: -f1); do
        losetup -d "$loop" 2>/dev/null
    done
    
    print_msg "$GREEN" "  ✓ Cleanup completed"
}

### Set trap for cleanup ###
trap cleanup EXIT

################################################################################
### MAIN EXECUTION
################################################################################

main() {
    print_header "OpenWRT CUSTOM BUILDER v1.0.0"
    
    ### Check if running as root ###
    check_root
    
    ### Setup directories ###
    setup_directories
    
    ### Setup logging ###
    setup_logging
    
    ### Check system requirements ###
    check_requirements
    
    ### Show configuration ###
    show_config
    
    ### Ask for confirmation ###
    confirm_build
    
    ### Execute build ###
    execute_build
    
    ### Post-build actions ###
    post_build
    
    print_header "BUILD COMPLETED SUCCESSFULLY"
    
    print_msg "$GREEN" "  Total build time: $SECONDS seconds"
    print_msg "$GREEN" "  Log file: $LOG_FILE"
    print_msg "$GREEN" ""
    print_msg "$WHITE" "  Next steps:"
    print_msg "$CYAN" "    1. Check output in: $OUTPUT_DIR"
    print_msg "$CYAN" "    2. Write to SD card: sudo $SCRIPT_DIR/scripts/write-sd.sh"
    print_msg "$CYAN" "    3. Boot your $TARGET_DEVICE"
    
    exit 0
}

### Run main function ###
main "$@"#!/bin/bash
################################################################################
### OpenWRT Custom Builder - Main Build Script
### BPI-R4 Debian/OpenWRT Hybrid Image Builder
################################################################################
### Project: OpenWRT Custom Builder
### Version: 1.0.0
### Author:  OpenWRT Builder Team
### Date:    2025-08-19
### License: MIT
################################################################################

################################################################################
### CONFIGURATION SECTION
################################################################################

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Create symbolic link to config if not exists
if [ ! -L "$SCRIPT_DIR/config" ]; then
    ln -sf "$PROJECT_ROOT/config" "$SCRIPT_DIR/config" 2>/dev/null
fi

# Load configuration
CONFIG_FILE="$PROJECT_ROOT/config/global.cfg"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "⚠️  Warning: Configuration file not found at $CONFIG_FILE"
    echo "   Using default values..."
fi

################################################################################
### DEFAULT CONFIGURATION (if global.cfg not found)
################################################################################

# Build Configuration
BUILD_TYPE="${BUILD_TYPE:-debian-luci}"
TARGET_DEVICE="${TARGET_DEVICE:-bpi-r4}"
IMAGE_SIZE="${IMAGE_SIZE:-8G}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"
WORK_DIR="${WORK_DIR:-$SCRIPT_DIR/work}"
LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/log}"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/cache}"

# System Configuration
DEBIAN_VERSION="${DEBIAN_VERSION:-bookworm}"
KERNEL_VERSION="${KERNEL_VERSION:-6.6}"
HOSTNAME="${HOSTNAME:-bpi-r4}"
ROOT_PASSWORD="${ROOT_PASSWORD:-bananapi}"
LAN_IP="${LAN_IP:-192.168.1.1}"
LAN_NETMASK="${LAN_NETMASK:-255.255.255.0}"

# Build Options
ENABLE_LUCI="${ENABLE_LUCI:-true}"
ENABLE_DOCKER="${ENABLE_DOCKER:-false}"
ENABLE_WIFI="${ENABLE_WIFI:-true}"
COMPRESS_IMAGE="${COMPRESS_IMAGE:-true}"
PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

################################################################################
### HELPER FUNCTIONS
################################################################################

### Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

### Print section header
print_header() {
    echo ""
    echo -e "${BLUE}################################################################################${NC}"
    echo -e "${BLUE}### $1${NC}"
    echo -e "${BLUE}################################################################################${NC}"
    echo ""
}

### Print sub-header
print_subheader() {
    echo ""
    echo -e "${CYAN}-----------------------------------------------------------------------------${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}-----------------------------------------------------------------------------${NC}"
}

### Error handling
error_exit() {
    print_msg "$RED" "❌ ERROR: $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    exit 1
}

### Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (sudo)"
    fi
}

### Create directory structure
setup_directories() {
    print_subheader "Setting up directory structure"
    
    local dirs=(
        "$OUTPUT_DIR"
        "$WORK_DIR"
        "$LOG_DIR"
        "$CACHE_DIR"
        "$SCRIPT_DIR/scripts"
        "$SCRIPT_DIR/boot"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_msg "$GREEN" "  ✓ Created: $dir"
        else
            print_msg "$WHITE" "  • Exists: $dir"
        fi
    done
}

### Setup logging
setup_logging() {
    LOG_FILE="$LOG_DIR/build_$(date '+%Y%m%d_%H%M%S').log"
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    echo "==============================================================================" >> "$LOG_FILE"
    echo "Build started at: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "Build type: $BUILD_TYPE" >> "$LOG_FILE"
    echo "Target device: $TARGET_DEVICE" >> "$LOG_FILE"
    echo "==============================================================================" >> "$LOG_FILE"
    
    print_msg "$GREEN" "  ✓ Logging to: $LOG_FILE"
}

### Check system requirements
check_requirements() {
    print_subheader "Checking system requirements"
    
    local required_commands=(
        "debootstrap"
        "parted"
        "mkfs.ext4"
        "mkfs.vfat"
        "rsync"
        "wget"
        "git"
        "xz"
    )
    
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
            print_msg "$RED" "  ✗ Missing: $cmd"
        else
            print_msg "$GREEN" "  ✓ Found: $cmd"
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_msg "$YELLOW" ""
        print_msg "$YELLOW" "Installing missing dependencies..."
        apt-get update
        apt-get install -y debootstrap parted dosfstools e2fsprogs \
                          rsync wget git xz-utils qemu-user-static \
                          device-tree-compiler u-boot-tools || \
            error_exit "Failed to install dependencies"
    fi
}

### Display build configuration
show_config() {
    print_header "BUILD CONFIGURATION"
    
    print_msg "$WHITE" "  Build Settings:"
    print_msg "$CYAN" "    • Build Type:      $BUILD_TYPE"
    print_msg "$CYAN" "    • Target Device:   $TARGET_DEVICE"
    print_msg "$CYAN" "    • Image Size:      $IMAGE_SIZE"
    print_msg "$CYAN" "    • Output Dir:      $OUTPUT_DIR"
    
    print_msg "$WHITE" ""
    print_msg "$WHITE" "  System Settings:"
    print_msg "$CYAN" "    • Debian Version:  $DEBIAN_VERSION"
    print_msg "$CYAN" "    • Kernel Version:  $KERNEL_VERSION"
    print_msg "$CYAN" "    • Hostname:        $HOSTNAME"
    print_msg "$CYAN" "    • LAN IP:          $LAN_IP"
    
    print_msg "$WHITE" ""
    print_msg "$WHITE" "  Build Options:"
    print_msg "$CYAN" "    • Enable LuCI:     $ENABLE_LUCI"
    print_msg "$CYAN" "    • Enable Docker:   $ENABLE_DOCKER"
    print_msg "$CYAN" "    • Enable WiFi:     $ENABLE_WIFI"
    print_msg "$CYAN" "    • Compress Image:  $COMPRESS_IMAGE"
    print_msg "$CYAN" "    • Parallel Jobs:   $PARALLEL_JOBS"
}

### Ask for confirmation
confirm_build() {
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "⚠️  This will create a new system image."
    print_msg "$WHITE" ""
    read -p "Do you want to continue? (yes/no): " -r response
    
    if [[ ! "$response" =~ ^[Yy]es$ ]]; then
        print_msg "$RED" "Build cancelled by user."
        exit 0
    fi
}

################################################################################
### BUILD FUNCTIONS
################################################################################

### Execute build script based on type
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
    
    if [ ! -f "$build_script" ]; then
        error_exit "Build script not found: $build_script"
    fi
    
    print_msg "$CYAN" "  Executing: $build_script"
    
    # Export variables for build script
    export OUTPUT_DIR WORK_DIR LOG_DIR CACHE_DIR
    export DEBIAN_VERSION KERNEL_VERSION HOSTNAME ROOT_PASSWORD
    export LAN_IP LAN_NETMASK IMAGE_SIZE
    export ENABLE_LUCI ENABLE_DOCKER ENABLE_WIFI
    export COMPRESS_IMAGE PARALLEL_JOBS
    export TARGET_DEVICE
    
    # Execute build script
    if bash "$build_script"; then
        print_msg "$GREEN" "  ✓ Build completed successfully!"
        return 0
    else
        error_exit "Build failed! Check log: $LOG_FILE"
    fi
}

### Post-build actions
post_build() {
    print_header "POST-BUILD ACTIONS"
    
    # List created images
    print_subheader "Created Images"
    if [ -d "$OUTPUT_DIR" ]; then
        ls -lh "$OUTPUT_DIR"/*.img* 2>/dev/null || print_msg "$YELLOW" "  No images found"
    fi
    
    # Check for SD card writer script
    if [ -f "$SCRIPT_DIR/scripts/write-sd.sh" ]; then
        print_msg "$WHITE" ""
        print_msg "$WHITE" "To write the image to SD card, run:"
        print_msg "$CYAN" "  sudo $SCRIPT_DIR/scripts/write-sd.sh"
    fi
    
    # Generate summary
    generate_summary
}

### Generate build summary
generate_summary() {
    local summary_file="$OUTPUT_DIR/build_summary.txt"
    
    {
        echo "=============================================================================="
        echo "BUILD SUMMARY"
        echo "=============================================================================="
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
        echo "=============================================================================="
    } > "$summary_file"
    
    print_msg "$GREEN" ""
    print_msg "$GREEN" "  ✓ Build summary saved to: $summary_file"
}

### Cleanup on exit
cleanup() {
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "Cleaning up..."
    
    # Unmount any mounted filesystems
    for mount in $(mount | grep "$WORK_DIR" | awk '{print $3}'); do
        umount "$mount" 2>/dev/null
    done
    
    # Remove loop devices
    for loop in $(losetup -a | grep "$WORK_DIR" | cut -d: -f1); do
        losetup -d "$loop" 2>/dev/null
    done
    
    print_msg "$GREEN" "  ✓ Cleanup completed"
}

### Set trap for cleanup
trap cleanup EXIT

################################################################################
### MAIN EXECUTION
################################################################################

main() {
    print_header "OpenWRT CUSTOM BUILDER v1.0.0"
    
    # Check if running as root
    check_root
    
    # Setup directories
    setup_directories
    
    # Setup logging
    setup_logging
    
    # Check system requirements
    check_requirements
    
    # Show configuration
    show_config
    
    # Ask for confirmation
    confirm_build
    
    # Execute build
    execute_build
    
    # Post-build actions
    post_build
    
    print_header "BUILD COMPLETED SUCCESSFULLY"
    
    print_msg "$GREEN" "  Total build time: $SECONDS seconds"
    print_msg "$GREEN" "  Log file: $LOG_FILE"
    print_msg "$GREEN" ""
    print_msg "$WHITE" "  Next steps:"
    print_msg "$CYAN" "    1. Check output in: $OUTPUT_DIR"
    print_msg "$CYAN" "    2. Write to SD card: sudo $SCRIPT_DIR/scripts/write-sd.sh"
    print_msg "$CYAN" "    3. Boot your $TARGET_DEVICE"
    
    exit 0
}

### Run main function
main "$@"