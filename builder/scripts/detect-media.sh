#!/bin/bash
################################################################################
### OpenWRT Custom Builder - Media Detection Script
### Detects and lists available USB/SD storage devices for image writing
################################################################################
### Project: OpenWRT Custom Builder
### Version: 1.0.0
### Author:  OpenWRT Builder Team
### Date:    2025-08-19
### License: MIT
################################################################################

set -e

################################################################################
### CONFIGURATION
################################################################################

### Script directory and paths ###
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_DIR="$(dirname "$SCRIPT_DIR")"

### Load configuration ###
if [ -f "$BUILDER_DIR/config/builder.cfg" ]; then
    source "$BUILDER_DIR/config/builder.cfg"
fi

### Colors for output ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

### Device detection settings ###
MIN_SIZE_GB=2        ### Minimum device size in GB ###
MAX_SIZE_GB=2000     ### Maximum device size in GB (safety limit) ###
EXCLUDE_BOOT_DEVICE="true"  ### Exclude device containing boot partition ###

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
    print_msg "$BLUE" "################################################################################"
    print_msg "$BLUE" "### $1"
    print_msg "$BLUE" "################################################################################"
    echo ""
}

### Print sub-header ###
print_subheader() {
    echo ""
    print_msg "$CYAN" "-----------------------------------------------------------------------------"
    print_msg "$CYAN" "  $1"
    print_msg "$CYAN" "-----------------------------------------------------------------------------"
}

### Convert bytes to human readable format ###
bytes_to_human() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $bytes -gt 1024 ] && [ $unit -lt ${#units[@]} ]; do
        bytes=$((bytes / 1024))
        ((unit++))
    done
    
    echo "${bytes}${units[$unit]}"
}

### Check if device is mounted ###
is_mounted() {
    local device=$1
    mount | grep -q "^${device}"
}

### Get device mount points ###
get_mount_points() {
    local device=$1
    mount | grep "^${device}" | awk '{print $3}' | tr '\n' ' '
}

### Get device filesystem type ###
get_filesystem() {
    local device=$1
    lsblk -no FSTYPE "$device" 2>/dev/null | head -1
}

### Get device label ###
get_label() {
    local device=$1
    lsblk -no LABEL "$device" 2>/dev/null | head -1
}

### Check if device contains boot partition ###
is_boot_device() {
    local device=$1
    
    ### Check if any partition is mounted as / or /boot ###
    for part in ${device}*; do
        [ -b "$part" ] || continue
        local mount_point=$(mount | grep "^${part} " | awk '{print $3}')
        if [ "$mount_point" = "/" ] || [ "$mount_point" = "/boot" ]; then
            return 0
        fi
    done
    
    ### Check if device contains current root filesystem ###
    local root_device=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
    if [ "$device" = "$root_device" ]; then
        return 0
    fi
    
    return 1
}

### Get device type (USB, SD, etc.) ###
get_device_type() {
    local device=$1
    local device_name=$(basename "$device")
    
    ### Check USB devices ###
    if [ -d "/sys/block/$device_name" ]; then
        local device_path=$(readlink -f "/sys/block/$device_name")
        
        if echo "$device_path" | grep -q "usb"; then
            echo "USB"
            return
        fi
        
        ### Check for SD card ###
        if echo "$device_name" | grep -qE "^mmc|^sd"; then
            echo "SD"
            return
        fi
        
        ### Check for SATA/IDE ###
        if echo "$device_name" | grep -qE "^sd[a-z]"; then
            echo "SATA"
            return
        fi
        
        ### Check for NVMe ###
        if echo "$device_name" | grep -qE "^nvme"; then
            echo "NVMe"
            return
        fi
    fi
    
    echo "Unknown"
}

### Get device vendor and model ###
get_device_info() {
    local device=$1
    local device_name=$(basename "$device")
    local vendor=""
    local model=""
    
    ### Try to get vendor and model from udev ###
    if command -v udevadm >/dev/null 2>&1; then
        local udev_info=$(udevadm info --query=property --name="$device" 2>/dev/null)
        vendor=$(echo "$udev_info" | grep "^ID_VENDOR=" | cut -d'=' -f2- | tr -d '"')
        model=$(echo "$udev_info" | grep "^ID_MODEL=" | cut -d'=' -f2- | tr -d '"')
    fi
    
    ### Fallback to sys filesystem ###
    if [ -z "$vendor" ] && [ -d "/sys/block/$device_name" ]; then
        vendor=$(cat "/sys/block/$device_name/device/vendor" 2>/dev/null | tr -d ' ')
        model=$(cat "/sys/block/$device_name/device/model" 2>/dev/null | tr -d ' ')
    fi
    
    ### Clean up strings ###
    vendor=$(echo "$vendor" | sed 's/[^a-zA-Z0-9_-]//g')
    model=$(echo "$model" | sed 's/[^a-zA-Z0-9_-]//g')
    
    if [ -n "$vendor" ] && [ -n "$model" ]; then
        echo "$vendor $model"
    elif [ -n "$model" ]; then
        echo "$model"
    elif [ -n "$vendor" ]; then
        echo "$vendor"
    else
        echo "Unknown Device"
    fi
}

### Check if device is suitable for imaging ###
is_suitable_device() {
    local device=$1
    local size_bytes=$2
    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
    
    ### Check minimum size ###
    if [ $size_gb -lt $MIN_SIZE_GB ]; then
        return 1
    fi
    
    ### Check maximum size (safety) ###
    if [ $size_gb -gt $MAX_SIZE_GB ]; then
        return 1
    fi
    
    ### Check if it's a boot device ###
    if [ "$EXCLUDE_BOOT_DEVICE" = "true" ] && is_boot_device "$device"; then
        return 1
    fi
    
    ### Check if it's a loop device ###
    if echo "$device" | grep -q "loop"; then
        return 1
    fi
    
    ### Check if it's a RAM disk ###
    if echo "$device" | grep -q "ram"; then
        return 1
    fi
    
    return 0
}

################################################################################
### DEVICE DETECTION FUNCTIONS
################################################################################

### Detect all block devices ###
detect_all_devices() {
    lsblk -dpno NAME,SIZE,TYPE | grep -E "disk$" | while read device size type; do
        ### Convert size to bytes ###
        local size_bytes=$(lsblk -bdno SIZE "$device" 2>/dev/null || echo 0)
        
        ### Check if device is suitable ###
        if is_suitable_device "$device" "$size_bytes"; then
            echo "$device $size_bytes"
        fi
    done
}

### Get detailed device information ###
get_device_details() {
    local device=$1
    local size_bytes=$2
    
    ### Calculate sizes ###
    local size_human=$(bytes_to_human "$size_bytes")
    local size_gb=$((size_bytes / 1024 / 1024 / 1024))
    
    ### Get device information ###
    local device_type=$(get_device_type "$device")
    local device_info=$(get_device_info "$device")
    local filesystem=$(get_filesystem "$device")
    local label=$(get_label "$device")
    local mount_status="Not mounted"
    local mount_points=""
    
    ### Check mount status ###
    if is_mounted "$device"; then
        mount_status="Mounted"
        mount_points=$(get_mount_points "$device")
    fi
    
    ### Check partitions ###
    local partition_count=$(lsblk -no NAME "$device" | grep -v "^$(basename "$device")$" | wc -l)
    
    ### Return structured information ###
    echo "$device|$size_bytes|$size_human|$size_gb|$device_type|$device_info|$filesystem|$label|$mount_status|$mount_points|$partition_count"
}

### List partitions of a device ###
list_partitions() {
    local device=$1
    
    print_msg "$WHITE" "    Partitions:"
    lsblk -no NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$device" | tail -n +2 | while read name size fstype label mountpoint; do
        if [ -n "$name" ]; then
            local part_device="/dev/$name"
            print_msg "$CYAN" "      • $part_device ($size) - $fstype"
            [ -n "$label" ] && print_msg "$CYAN" "        Label: $label"
            [ -n "$mountpoint" ] && print_msg "$YELLOW" "        Mounted: $mountpoint"
        fi
    done
}

################################################################################
### MAIN DETECTION LOGIC
################################################################################

### Main device detection and listing ###
detect_and_list_devices() {
    print_header "Storage Device Detection"
    
    print_msg "$WHITE" "Scanning for suitable storage devices..."
    print_msg "$CYAN" "Criteria: ${MIN_SIZE_GB}GB - ${MAX_SIZE_GB}GB, excluding boot devices"
    echo ""
    
    ### Detect devices ###
    local devices=$(detect_all_devices)
    local device_count=0
    local device_array=()
    
    if [ -z "$devices" ]; then
        print_msg "$YELLOW" "⚠️  No suitable storage devices found."
        echo ""
        print_msg "$WHITE" "Requirements:"
        print_msg "$CYAN" "  • Minimum size: ${MIN_SIZE_GB}GB"
        print_msg "$CYAN" "  • Maximum size: ${MAX_SIZE_GB}GB"
        print_msg "$CYAN" "  • Not the boot device"
        print_msg "$CYAN" "  • Not a virtual device (loop, ram)"
        echo ""
        print_msg "$WHITE" "Available devices (all sizes):"
        lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
        return 1
    fi
    
    ### Process each device ###
    echo "$devices" | while read device size_bytes; do
        [ -z "$device" ] && continue
        
        device_count=$((device_count + 1))
        device_array+=("$device")
        
        ### Get detailed information ###
        local details=$(get_device_details "$device" "$size_bytes")
        IFS='|' read -r dev size_b size_h size_gb type info fs label mount_status mount_points part_count <<< "$details"
        
        ### Display device information ###
        print_subheader "Device $device_count: $device"
        
        print_msg "$WHITE" "  Device Information:"
        print_msg "$CYAN" "    • Type:       $type"
        print_msg "$CYAN" "    • Model:      $info"
        print_msg "$CYAN" "    • Size:       $size_h (${size_gb}GB)"
        print_msg "$CYAN" "    • Device:     $device"
        
        if [ -n "$fs" ]; then
            print_msg "$CYAN" "    • Filesystem: $fs"
        fi
        
        if [ -n "$label" ]; then
            print_msg "$CYAN" "    • Label:      $label"
        fi
        
        ### Mount status ###
        if [ "$mount_status" = "Mounted" ]; then
            print_msg "$YELLOW" "    • Status:     $mount_status ($mount_points)"
        else
            print_msg "$GREEN" "    • Status:     $mount_status"
        fi
        
        ### Partition information ###
        if [ "$part_count" -gt 0 ]; then
            print_msg "$CYAN" "    • Partitions: $part_count"
            list_partitions "$device"
        else
            print_msg "$CYAN" "    • Partitions: None (unpartitioned)"
        fi
        
        ### Safety warnings ###
        if [ "$mount_status" = "Mounted" ]; then
            print_msg "$YELLOW" "    ⚠️  WARNING: Device is currently mounted!"
        fi
        
        if [ "$part_count" -gt 0 ]; then
            print_msg "$YELLOW" "    ⚠️  WARNING: Device contains partitions that will be destroyed!"
        fi
        
        echo ""
    done
    
    ### Summary ###
    local total_devices=$(echo "$devices" | wc -l)
    if [ "$total_devices" -eq 1 ]; then
        print_msg "$GREEN" "✅ Found $total_devices suitable device"
    else
        print_msg "$GREEN" "✅ Found $total_devices suitable devices"
    fi
    
    return 0
}

### Interactive device selection ###
select_device_interactive() {
    print_header "Device Selection"
    
    ### Get devices again for selection ###
    local devices=$(detect_all_devices)
    local device_array=()
    local device_info_array=()
    local count=0
    
    if [ -z "$devices" ]; then
        print_msg "$RED" "❌ No suitable devices available for selection."
        return 1
    fi
    
    ### Build device arrays ###
    echo "$devices" | while read device size_bytes; do
        [ -z "$device" ] && continue
        count=$((count + 1))
        device_array+=("$device")
        
        local details=$(get_device_details "$device" "$size_bytes")
        IFS='|' read -r dev size_b size_h size_gb type info fs label mount_status mount_points part_count <<< "$details"
        device_info_array+=("$type $info ($size_h)")
        
        print_msg "$WHITE" "  [$count] $device - $type $info ($size_h)"
        
        if [ "$mount_status" = "Mounted" ]; then
            print_msg "$YELLOW" "      ⚠️  Currently mounted at: $mount_points"
        fi
        
        if [ "$part_count" -gt 0 ]; then
            print_msg "$YELLOW" "      ⚠️  Contains $part_count partition(s)"
        fi
    done
    
    echo ""
    print_msg "$WHITE" "  [0] Cancel / Exit"
    echo ""
    
    ### Get user selection ###
    while true; do
        read -p "Please select a device [0-$count]: " selection
        
        if [ "$selection" = "0" ]; then
            print_msg "$YELLOW" "Operation cancelled by user."
            return 1
        elif [ "$selection" -ge 1 ] && [ "$selection" -le "$count" ] 2>/dev/null; then
            local selected_index=$((selection - 1))
            local selected_device=${device_array[$selected_index]}
            
            ### Show final confirmation ###
            print_msg "$WHITE" ""
            print_msg "$RED" "⚠️  FINAL WARNING ⚠️"
            print_msg "$WHITE" "Selected device: $selected_device"
            print_msg "$WHITE" "This will COMPLETELY ERASE all data on this device!"
            print_msg "$WHITE" ""
            read -p "Type 'YES' to confirm: " confirmation
            
            if [ "$confirmation" = "YES" ]; then
                echo "$selected_device"
                return 0
            else
                print_msg "$YELLOW" "Confirmation failed. Operation cancelled."
                return 1
            fi
        else
            print_msg "$RED" "Invalid selection. Please enter a number between 0 and $count."
        fi
    done
}

### Export device information ###
export_device_info() {
    local output_file="${1:-/tmp/detected_devices.txt}"
    
    print_header "Exporting Device Information"
    
    {
        echo "################################################################################"
        echo "### Storage Device Detection Report"
        echo "### Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "################################################################################"
        echo ""
        echo "Detection Criteria:"
        echo "  Minimum Size: ${MIN_SIZE_GB}GB"
        echo "  Maximum Size: ${MAX_SIZE_GB}GB"
        echo "  Exclude Boot:  $EXCLUDE_BOOT_DEVICE"
        echo ""
        echo "Detected Devices:"
        echo "=================="
        
        local devices=$(detect_all_devices)
        local count=0
        
        if [ -n "$devices" ]; then
            echo "$devices" | while read device size_bytes; do
                [ -z "$device" ] && continue
                count=$((count + 1))
                
                local details=$(get_device_details "$device" "$size_bytes")
                IFS='|' read -r dev size_b size_h size_gb type info fs label mount_status mount_points part_count <<< "$details"
                
                echo ""
                echo "Device $count: $device"
                echo "  Type:        $type"
                echo "  Model:       $info"
                echo "  Size:        $size_h (${size_gb}GB)"
                echo "  Filesystem:  $fs"
                echo "  Label:       $label"
                echo "  Status:      $mount_status $mount_points"
                echo "  Partitions:  $part_count"
            done
        else
            echo ""
            echo "No suitable devices found."
        fi
        
        echo ""
        echo "################################################################################"
        
    } > "$output_file"
    
    print_msg "$GREEN" "Device information exported to: $output_file"
}

################################################################################
### COMMAND LINE INTERFACE
################################################################################

### Show usage information ###
show_usage() {
    cat << EOF
################################################################################
### OpenWRT Builder - Storage Device Detection
################################################################################

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    detect          Detect and list all suitable devices (default)
    select          Interactive device selection
    export [FILE]   Export device information to file
    list-all        Show all block devices (including unsuitable)
    
OPTIONS:
    -h, --help         Show this help message
    -q, --quiet        Quiet mode (minimal output)
    -v, --verbose      Verbose mode (detailed output)
    --min-size SIZE    Minimum device size in GB (default: $MIN_SIZE_GB)
    --max-size SIZE    Maximum device size in GB (default: $MAX_SIZE_GB)
    --include-boot     Include boot device in detection
    --json             Output in JSON format

EXAMPLES:
    $0                          # Detect suitable devices
    $0 select                   # Interactive device selection
    $0 export devices.txt       # Export to file
    $0 --min-size 4 detect      # Only devices >= 4GB
    $0 --include-boot detect    # Include boot device

SAFETY:
    This script automatically excludes:
    - Devices smaller than ${MIN_SIZE_GB}GB
    - Devices larger than ${MAX_SIZE_GB}GB
    - Boot device (containing / or /boot)
    - Virtual devices (loop, ram)

EOF
}

################################################################################
### MAIN EXECUTION
################################################################################

### Parse command line arguments ###
QUIET_MODE=false
VERBOSE_MODE=false
JSON_OUTPUT=false
COMMAND="detect"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        --min-size)
            MIN_SIZE_GB="$2"
            shift 2
            ;;
        --max-size)
            MAX_SIZE_GB="$2"
            shift 2
            ;;
        --include-boot)
            EXCLUDE_BOOT_DEVICE=false
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        detect|select|export|list-all)
            COMMAND="$1"
            shift
            ;;
        *)
            if [ "$COMMAND" = "export" ] && [ -z "$EXPORT_FILE" ]; then
                EXPORT_FILE="$1"
            else
                print_msg "$RED" "Unknown option: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

### Check if running as root for some operations ###
check_root_access() {
    if [ "$COMMAND" = "select" ] && [[ $EUID -ne 0 ]]; then
        print_msg "$YELLOW" "⚠️  Note: Root access recommended for device operations"
    fi
}

### Main execution ###
main() {
    ### Set output mode ###
    if [ "$QUIET_MODE" = "true" ]; then
        exec 2>/dev/null
    fi
    
    ### Check dependencies ###
    for cmd in lsblk mount df; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_msg "$RED" "❌ Required command not found: $cmd"
            exit 1
        fi
    done
    
    ### Execute command ###
    case "$COMMAND" in
        detect)
            if [ "$JSON_OUTPUT" = "true" ]; then
                ### JSON output implementation would go here ###
                print_msg "$YELLOW" "JSON output not yet implemented"
                exit 1
            else
                detect_and_list_devices
            fi
            ;;
        select)
            check_root_access
            selected_device=$(select_device_interactive)
            if [ $? -eq 0 ] && [ -n "$selected_device" ]; then
                print_msg "$GREEN" "Selected device: $selected_device"
                echo "$selected_device"
            fi
            ;;
        export)
            export_device_info "${EXPORT_FILE:-/tmp/detected_devices.txt}"
            ;;
        list-all)
            print_header "All Block Devices"
            lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT
            ;;
        *)
            print_msg "$RED" "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
}

### Run main function ###
main "$@"