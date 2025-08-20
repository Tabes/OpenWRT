#!/bin/bash
################################################################################
### OpenWRT Custom Builder - Image Writer Script
### Writes system images to USB/SD storage devices safely
################################################################################
### Project: OpenWRT Custom Builder
### Version: 1.0.0
### Author:  OpenWRT Builder Team
### Date:    2025-08-19
### License: MIT
################################################################################

set -e

################################################################################
### INITIALIZATION
################################################################################

### Script directory and paths ###
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_DIR="$(dirname "$SCRIPT_DIR")"

### Load helper functions ###
if [ -f "$SCRIPT_DIR/helper.sh" ]; then
    source "$SCRIPT_DIR/helper.sh"
else
    echo "ERROR: Helper functions not found at $SCRIPT_DIR/helper.sh"
    exit 1
fi

### Load configuration ###
load_config "$BUILDER_DIR/config/builder.cfg" false

################################################################################
### CONFIGURATION
################################################################################

### Image writing settings ###
DEFAULT_BLOCK_SIZE="4M"
DEFAULT_SYNC_INTERVAL="10"  ### Sync every N MB ###
VERIFICATION_ENABLED="${VERIFICATION_ENABLED:-true}"
PROGRESS_UPDATE_INTERVAL="1"  ### Seconds ###
MAX_WRITE_RETRIES=3

### Safety settings ###
REQUIRE_CONFIRMATION="${REQUIRE_CONFIRMATION:-true}"
FORCE_MODE="${FORCE_MODE:-false}"
ALLOW_MOUNTED_TARGET="${ALLOW_MOUNTED_TARGET:-false}"

### Initialize with logging ###
LOG_FILE="${LOG_DIR:-/tmp}/write-media-$(get_timestamp).log"
init_helpers "write-media.sh" "$LOG_FILE"

################################################################################
### IMAGE DETECTION AND VALIDATION
################################################################################

### Find available images ###
find_images() {
    local search_dir="${1:-$OUTPUT_DIR}"
    local pattern="${2:-*.img*}"
    
    if [ ! -d "$search_dir" ]; then
        print_error "Image directory not found: $search_dir"
        return 1
    fi
    
    ### Find image files ###
    find "$search_dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | sort -t/ -k2
}

### Get image information ###
get_image_info() {
    local image_file="$1"
    local file_size=$(stat -c%s "$image_file" 2>/dev/null || echo 0)
    local file_size_human=$(bytes_to_human "$file_size")
    local file_type="Unknown"
    local compression="None"
    
    ### Determine file type and compression ###
    case "$image_file" in
        *.img.xz)   file_type="Raw Image"; compression="XZ" ;;
        *.img.gz)   file_type="Raw Image"; compression="GZIP" ;;
        *.img.bz2)  file_type="Raw Image"; compression="BZIP2" ;;
        *.img.zst)  file_type="Raw Image"; compression="ZSTD" ;;
        *.img)      file_type="Raw Image"; compression="None" ;;
        *.iso)      file_type="ISO Image"; compression="None" ;;
        *)          file_type="Unknown" ;;
    esac
    
    ### Get creation date ###
    local creation_date=$(stat -c%y "$image_file" 2>/dev/null | cut -d' ' -f1)
    
    echo "$file_size|$file_size_human|$file_type|$compression|$creation_date"
}

### Validate image file ###
validate_image() {
    local image_file="$1"
    
    ### Check if file exists ###
    if [ ! -f "$image_file" ]; then
        print_error "Image file not found: $image_file"
        return 1
    fi
    
    ### Check file size ###
    local file_size=$(stat -c%s "$image_file" 2>/dev/null || echo 0)
    if [ "$file_size" -eq 0 ]; then
        print_error "Image file is empty: $image_file"
        return 1
    fi
    
    ### Check minimum size (1MB) ###
    if [ "$file_size" -lt 1048576 ]; then
        print_error "Image file too small (< 1MB): $image_file"
        return 1
    fi
    
    ### Check if compressed file is valid ###
    case "$image_file" in
        *.xz)
            if ! xz -t "$image_file" 2>/dev/null; then
                print_error "Invalid XZ archive: $image_file"
                return 1
            fi
            ;;
        *.gz)
            if ! gzip -t "$image_file" 2>/dev/null; then
                print_error "Invalid GZIP archive: $image_file"
                return 1
            fi
            ;;
        *.bz2)
            if ! bzip2 -t "$image_file" 2>/dev/null; then
                print_error "Invalid BZIP2 archive: $image_file"
                return 1
            fi
            ;;
    esac
    
    print_success "Image validation passed: $(basename "$image_file")"
    return 0
}

### Calculate decompressed size ###
get_decompressed_size() {
    local image_file="$1"
    local decompressed_size=0
    
    case "$image_file" in
        *.img.xz)
            ### XZ can show uncompressed size ###
            decompressed_size=$(xz -l "$image_file" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d ',')
            ;;
        *.img.gz)
            ### GZIP shows uncompressed size in last 4 bytes ###
            decompressed_size=$(gzip -l "$image_file" 2>/dev/null | tail -1 | awk '{print $2}')
            ;;
        *.img)
            ### Uncompressed image ###
            decompressed_size=$(stat -c%s "$image_file")
            ;;
        *)
            ### Unknown, use file size as approximation ###
            decompressed_size=$(stat -c%s "$image_file")
            ;;
    esac
    
    echo "${decompressed_size:-0}"
}

################################################################################
### DEVICE VALIDATION AND PREPARATION
################################################################################

### Check target device ###
validate_target_device() {
    local device="$1"
    
    ### Check if device exists ###
    if [ ! -b "$device" ]; then
        print_error "Device not found or not a block device: $device"
        return 1
    fi
    
    ### Check if device is a partition ###
    if echo "$device" | grep -qE '[0-9]+$'; then
        print_warning "Warning: Target appears to be a partition, not a whole device"
        if [ "$FORCE_MODE" != "true" ]; then
            if ! ask_yes_no "Continue anyway?" "no"; then
                return 1
            fi
        fi
    fi
    
    ### Check if device is mounted ###
    if mount | grep -q "^${device}"; then
        print_error "Device is currently mounted: $device"
        if [ "$ALLOW_MOUNTED_TARGET" != "true" ]; then
            print_info "Mounted partitions:"
            mount | grep "^${device}" | while read line; do
                print_bullet 1 "$line"
            done
            
            if ask_yes_no "Unmount all partitions?" "no"; then
                unmount_device "$device"
            else
                return 1
            fi
        fi
    fi
    
    ### Check device size ###
    local device_size=$(lsblk -bdno SIZE "$device" 2>/dev/null || echo 0)
    if [ "$device_size" -eq 0 ]; then
        print_error "Cannot determine device size: $device"
        return 1
    fi
    
    print_success "Target device validated: $device ($(bytes_to_human "$device_size"))"
    return 0
}

### Unmount device and all partitions ###
unmount_device() {
    local device="$1"
    local unmounted=false
    
    print_info "Unmounting partitions on $device..."
    
    ### Find all mounted partitions ###
    mount | grep "^${device}" | awk '{print $1}' | while read partition; do
        print_info "Unmounting: $partition"
        if safe_unmount "$partition"; then
            unmounted=true
        else
            print_error "Failed to unmount: $partition"
            return 1
        fi
    done
    
    ### Wait a moment for system to settle ###
    sleep 2
    
    ### Verify all partitions are unmounted ###
    if mount | grep -q "^${device}"; then
        print_error "Some partitions are still mounted"
        return 1
    fi
    
    print_success "All partitions unmounted successfully"
    return 0
}

### Check if target device is large enough ###
check_device_capacity() {
    local device="$1"
    local required_size="$2"
    
    local device_size=$(lsblk -bdno SIZE "$device" 2>/dev/null || echo 0)
    
    if [ "$device_size" -lt "$required_size" ]; then
        local device_size_human=$(bytes_to_human "$device_size")
        local required_size_human=$(bytes_to_human "$required_size")
        
        print_error "Device too small for image"
        print_bullet 0 "Device size: $device_size_human"
        print_bullet 0 "Required:    $required_size_human"
        return 1
    fi
    
    print_success "Device capacity check passed"
    return 0
}

################################################################################
### IMAGE WRITING FUNCTIONS
################################################################################

### Get decompression command ###
get_decompress_cmd() {
    local image_file="$1"
    
    case "$image_file" in
        *.img.xz)   echo "xzcat" ;;
        *.img.gz)   echo "zcat" ;;
        *.img.bz2)  echo "bzcat" ;;
        *.img.zst)  echo "zstdcat" ;;
        *.img)      echo "cat" ;;
        *)          echo "cat" ;;
    esac
}

### Write image with progress ###
write_image_with_progress() {
    local image_file="$1"
    local target_device="$2"
    local block_size="${3:-$DEFAULT_BLOCK_SIZE}"
    
    local decompress_cmd=$(get_decompress_cmd "$image_file")
    local total_size=$(get_decompressed_size "$image_file")
    local start_time=$SECONDS
    
    print_info "Writing image to $target_device..."
    print_bullet 0 "Block size: $block_size"
    print_bullet 0 "Total size: $(bytes_to_human "$total_size")"
    
    ### Create named pipe for progress monitoring ###
    local progress_pipe="/tmp/write_progress_$$"
    mkfifo "$progress_pipe"
    
    ### Start progress monitor in background ###
    monitor_write_progress "$target_device" "$total_size" &
    local monitor_pid=$!
    
    ### Execute write command ###
    local write_cmd="$decompress_cmd '$image_file' | dd of='$target_device' bs='$block_size' oflag=direct,sync status=progress"
    
    log_info "Executing: $write_cmd"
    
    if eval "$write_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        ### Kill progress monitor ###
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true
        
        ### Final sync ###
        print_info "Synchronizing data to device..."
        sync
        
        local duration=$((SECONDS - start_time))
        print_success "Image written successfully in $(format_duration "$duration")"
        
        ### Clean up ###
        rm -f "$progress_pipe"
        return 0
    else
        ### Kill progress monitor ###
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true
        rm -f "$progress_pipe"
        
        print_error "Image writing failed"
        return 1
    fi
}

### Monitor write progress ###
monitor_write_progress() {
    local device="$1"
    local total_size="$2"
    local last_written=0
    local start_time=$SECONDS
    
    while true; do
        ### Check if device exists (write might be complete) ###
        if [ ! -b "$device" ]; then
            break
        fi
        
        ### Get current written bytes (approximation) ###
        local current_written=$(grep -E "$(basename "$device")" /proc/diskstats 2>/dev/null | awk '{print $10 * 512}' || echo 0)
        
        if [ "$current_written" -gt "$last_written" ]; then
            local percentage=0
            if [ "$total_size" -gt 0 ]; then
                percentage=$((current_written * 100 / total_size))
                [ $percentage -gt 100 ] && percentage=100
            fi
            
            local elapsed=$((SECONDS - start_time))
            local speed=0
            if [ $elapsed -gt 0 ]; then
                speed=$((current_written / elapsed))
            fi
            
            print_progress "$current_written" "$total_size" "Written: $(bytes_to_human "$current_written") @ $(bytes_to_human "$speed")/s"
            last_written="$current_written"
        fi
        
        sleep "$PROGRESS_UPDATE_INTERVAL"
    done
}

### Verify written image ###
verify_image() {
    local image_file="$1"
    local target_device="$2"
    
    if [ "$VERIFICATION_ENABLED" != "true" ]; then
        print_info "Image verification skipped"
        return 0
    fi
    
    print_info "Verifying written image..."
    
    local decompress_cmd=$(get_decompress_cmd "$image_file")
    local image_size=$(get_decompressed_size "$image_file")
    
    ### Calculate checksums ###
    print_info "Calculating image checksum..."
    local image_checksum=$(eval "$decompress_cmd '$image_file'" | sha256sum | awk '{print $1}')
    
    print_info "Calculating device checksum..."
    local device_checksum=$(dd if="$target_device" bs=1M count=$((image_size / 1024 / 1024 + 1)) 2>/dev/null | sha256sum | awk '{print $1}')
    
    if [ "$image_checksum" = "$device_checksum" ]; then
        print_success "Image verification passed"
        return 0
    else
        print_error "Image verification failed"
        print_bullet 0 "Image checksum:  $image_checksum"
        print_bullet 0 "Device checksum: $device_checksum"
        return 1
    fi
}

################################################################################
### USER INTERFACE FUNCTIONS
################################################################################

### Select image interactively ###
select_image_interactive() {
    local search_dir="${1:-$OUTPUT_DIR}"
    
    print_header "Image Selection"
    
    ### Find available images ###
    local images=($(find_images "$search_dir"))
    
    if [ ${#images[@]} -eq 0 ]; then
        print_error "No images found in: $search_dir"
        print_info "Looking for files matching: *.img*"
        return 1
    fi
    
    ### Display available images ###
    print_info "Available images:"
    
    for i in "${!images[@]}"; do
        local image="${images[$i]}"
        local image_info=$(get_image_info "$image")
        IFS='|' read -r size size_human type compression date <<< "$image_info"
        
        print_msg "$WHITE" "  [$((i+1))] $(basename "$image")"
        print_bullet 1 "Size: $size_human ($type)"
        print_bullet 1 "Compression: $compression"
        print_bullet 1 "Date: $date"
        echo ""
    done
    
    print_msg "$WHITE" "  [0] Cancel"
    echo ""
    
    ### Get user selection ###
    while true; do
        read -p "Please select an image [0-${#images[@]}]: " selection
        
        if [ "$selection" = "0" ]; then
            print_info "Selection cancelled by user"
            return 1
        elif [ "$selection" -ge 1 ] && [ "$selection" -le "${#images[@]}" ] 2>/dev/null; then
            local selected_image="${images[$((selection - 1))]}"
            echo "$selected_image"
            return 0
        else
            print_warning "Invalid selection. Please enter a number between 0 and ${#images[@]}"
        fi
    done
}

### Select target device interactively ###
select_target_interactive() {
    print_header "Target Device Selection"
    
    ### Use detect-media.sh if available ###
    if [ -f "$SCRIPT_DIR/detect-media.sh" ]; then
        print_info "Using device detection script..."
        if "$SCRIPT_DIR/detect-media.sh" select; then
            return 0
        else
            return 1
        fi
    else
        ### Fallback to manual selection ###
        print_warning "Device detection script not found, using manual selection"
        
        print_info "Available block devices:"
        lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
        echo ""
        
        while true; do
            read -p "Enter target device (e.g., /dev/sdb): " device
            
            if [ -z "$device" ]; then
                print_warning "Please enter a device path"
                continue
            fi
            
            if [ ! -b "$device" ]; then
                print_error "Not a valid block device: $device"
                continue
            fi
            
            echo "$device"
            return 0
        done
    fi
}

### Show write summary and confirmation ###
show_write_summary() {
    local image_file="$1"
    local target_device="$2"
    
    ### Get image information ###
    local image_info=$(get_image_info "$image_file")
    IFS='|' read -r size size_human type compression date <<< "$image_info"
    
    ### Get device information ###
    local device_size=$(lsblk -bdno SIZE "$target_device" 2>/dev/null || echo 0)
    local device_size_human=$(bytes_to_human "$device_size")
    local device_model=$(lsblk -no MODEL "$target_device" 2>/dev/null | head -1)
    
    print_box "WRITE OPERATION SUMMARY" \
        "Source Image:    $(basename "$image_file")
Image Size:      $size_human
Image Type:      $type
Compression:     $compression

Target Device:   $target_device
Device Size:     $device_size_human
Device Model:    $device_model

⚠️  WARNING: ALL DATA ON THE TARGET DEVICE WILL BE DESTROYED!"
    
    if [ "$REQUIRE_CONFIRMATION" = "true" ] && [ "$FORCE_MODE" != "true" ]; then
        echo ""
        if ! ask_yes_no "Are you absolutely sure you want to continue?" "no"; then
            print_info "Operation cancelled by user"
            return 1
        fi
    fi
    
    return 0
}

################################################################################
### MAIN WRITING LOGIC
################################################################################

### Write image to device with retry ###
write_image_with_retry() {
    local image_file="$1"
    local target_device="$2"
    local attempt=1
    
    while [ $attempt -le $MAX_WRITE_RETRIES ]; do
        print_info "Write attempt $attempt of $MAX_WRITE_RETRIES"
        
        if write_image_with_progress "$image_file" "$target_device"; then
            ### Verify if enabled ###
            if [ "$VERIFICATION_ENABLED" = "true" ]; then
                if verify_image "$image_file" "$target_device"; then
                    return 0
                else
                    print_warning "Verification failed, retrying..."
                fi
            else
                return 0
            fi
        else
            print_warning "Write failed, retrying..."
        fi
        
        attempt=$((attempt + 1))
        
        if [ $attempt -le $MAX_WRITE_RETRIES ]; then
            print_info "Waiting 5 seconds before retry..."
            sleep 5
        fi
    done
    
    print_error "All write attempts failed"
    return 1
}

### Main write function ###
write_image_main() {
    local image_file="$1"
    local target_device="$2"
    
    ### Validate inputs ###
    validate_image "$image_file" || return 1
    validate_target_device "$target_device" || return 1
    
    ### Check capacity ###
    local required_size=$(get_decompressed_size "$image_file")
    check_device_capacity "$target_device" "$required_size" || return 1
    
    ### Show summary and get confirmation ###
    show_write_summary "$image_file" "$target_device" || return 1
    
    ### Write image ###
    local start_time=$SECONDS
    
    if write_image_with_retry "$image_file" "$target_device"; then
        local duration=$((SECONDS - start_time))
        
        print_success "Image written successfully!"
        print_bullet 0 "Total time: $(format_duration "$duration")"
        print_bullet 0 "Target: $target_device"
        
        ### Show next steps ###
        print_info "Next steps:"
        print_bullet 0 "Safely remove the device"
        print_bullet 0 "Insert into target system"
        print_bullet 0 "Power on and enjoy!"
        
        return 0
    else
        print_error "Failed to write image"
        return 1
    fi
}

################################################################################
### COMMAND LINE INTERFACE
################################################################################

### Show usage information ###
show_usage() {
    print_header "OpenWRT Builder - Image Writer v1.0.0"
    
    print_msg "$WHITE" "USAGE:"
    print_msg "$CYAN" "    $0 [OPTIONS] [IMAGE] [DEVICE]"
    echo ""
    
    print_msg "$WHITE" "ARGUMENTS:"
    print_msg "$CYAN" "    IMAGE           Path to image file (will prompt if not specified)"
    print_msg "$CYAN" "    DEVICE          Target device (will prompt if not specified)"
    echo ""
    
    print_msg "$WHITE" "OPTIONS:"
    print_msg "$GREEN" "    -h, --help           ${WHITE}Show this help message"
    print_msg "$GREEN" "    -f, --force          ${WHITE}Force mode (skip confirmations)"
    print_msg "$GREEN" "    -q, --quiet          ${WHITE}Quiet mode (minimal output)"
    print_msg "$GREEN" "    -v, --verbose        ${WHITE}Verbose mode (detailed output)"
    print_msg "$GREEN" "    -d, --dir DIR        ${WHITE}Directory to search for images"
    print_msg "$GREEN" "    --no-verify          ${WHITE}Skip image verification after writing"
    print_msg "$GREEN" "    --allow-mounted      ${WHITE}Allow writing to mounted devices"
    print_msg "$GREEN" "    --block-size SIZE    ${WHITE}Block size for dd (default: $DEFAULT_BLOCK_SIZE)"
    print_msg "$GREEN" "    --no-progress        ${WHITE}Disable progress monitoring"
    echo ""
    
    print_msg "$WHITE" "EXAMPLES:"
    print_msg "$YELLOW" "    $0                                    ${DIM}# Interactive mode"
    print_msg "$YELLOW" "    $0 image.img.xz /dev/sdb             ${DIM}# Write specific image"
    print_msg "$YELLOW" "    $0 -d /opt/images                    ${DIM}# Select from custom directory"
    print_msg "$YELLOW" "    $0 --force --no-verify image.img    ${DIM}# Fast write without verification"
    echo ""
    
    print_msg "$WHITE" "SUPPORTED FORMATS:"
    print_bullet 0 "Raw images: *.img"
    print_bullet 0 "Compressed: *.img.xz, *.img.gz, *.img.bz2, *.img.zst"
    print_bullet 0 "ISO images: *.iso"
    echo ""
    
    print_box "SAFETY FEATURES" \
        "• Target device will be completely overwritten
• All existing partitions and data will be destroyed
• Boot device is automatically excluded from selection
• Mounted devices require explicit permission
• Confirmation required unless --force is used
• Optional verification after writing
• Automatic retry on write failures"
    
    print_msg "$WHITE" "DEVICE SELECTION:"
    print_bullet 0 "Automatic detection of suitable devices"
    print_bullet 0 "Interactive selection if multiple devices found"
    print_bullet 0 "Size validation (image must fit on device)"
    print_bullet 0 "Integration with detect-media.sh"
    echo ""
    
    print_msg "$WHITE" "WRITE PROCESS:"
    print_bullet 0 "Automatic decompression of compressed images"
    print_bullet 0 "Real-time progress monitoring with speed display"
    print_bullet 0 "Direct I/O for optimal performance"
    print_bullet 0 "Automatic sync and verification"
    print_bullet 0 "Detailed logging of all operations"
    echo ""
    
    print_msg "$CYAN" "For more information, visit: https://github.com/Tabes/OpenWRT"
}

### Parse command line arguments ###
parse_arguments() {
    IMAGE_FILE=""
    TARGET_DEVICE=""
    IMAGE_DIR="$OUTPUT_DIR"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--force)
                FORCE_MODE=true
                REQUIRE_CONFIRMATION=false
                shift
                ;;
            -q|--quiet)
                DEFAULT_QUIET_MODE=true
                shift
                ;;
            -v|--verbose)
                DEFAULT_VERBOSE_MODE=true
                shift
                ;;
            -d|--dir)
                IMAGE_DIR="$2"
                shift 2
                ;;
            --no-verify)
                VERIFICATION_ENABLED=false
                shift
                ;;
            --allow-mounted)
                ALLOW_MOUNTED_TARGET=true
                shift
                ;;
            --block-size)
                DEFAULT_BLOCK_SIZE="$2"
                shift 2
                ;;
            --no-progress)
                PROGRESS_UPDATE_INTERVAL=0
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$IMAGE_FILE" ]; then
                    IMAGE_FILE="$1"
                elif [ -z "$TARGET_DEVICE" ]; then
                    TARGET_DEVICE="$1"
                else
                    print_error "Too many arguments"
                    show_usage
                    exit 1
                fi
                shift
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
    
    ### Check if running as root ###
    check_root
    
    ### Check required commands ###
    check_required_commands dd sync lsblk mount stat sha256sum
    
    ### Show header ###
    print_header "OpenWRT Builder - Image Writer"
    
    ### Select image if not provided ###
    if [ -z "$IMAGE_FILE" ]; then
        if ! IMAGE_FILE=$(select_image_interactive "$IMAGE_DIR"); then
            exit 1
        fi
    fi
    
    ### Select target device if not provided ###
    if [ -z "$TARGET_DEVICE" ]; then
        if ! TARGET_DEVICE=$(select_target_interactive); then
            exit 1
        fi
    fi
    
    ### Execute main write operation ###
    if write_image_main "$IMAGE_FILE" "$TARGET_DEVICE"; then
        log_info "Image writing completed successfully"
        exit 0
    else
        log_error "Image writing failed"
        exit 1
    fi
}

### Run main function ###
main "$@"