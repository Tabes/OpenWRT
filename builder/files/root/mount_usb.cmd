#!/bin/ash
### BPI-R4 USB Mount and Configuration Starter Script ###
set -e
USB_MOUNT_POINT="/mnt/usb"
OPENWRT_PATH="$USB_MOUNT_POINT/OpenWRT"
LOG_FILE="/tmp/usb_mount_$(date +%Y%m%d_%H%M%S).log"

log_message() {
    echo "[$( date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo "================================================================================"
log_message "BPI-R4 USB Mount Script - Enhanced Version"
echo "================================================================================"

sleep 3
USB_DEVICE=$(ls /dev/sd?1 /dev/mmcblk1p1 2>/dev/null | head -1)

if [ -n "$USB_DEVICE" ]; then
    log_message "Found USB device: $USB_DEVICE"
    mkdir -p "$USB_MOUNT_POINT"
    
    if mount "$USB_DEVICE" "$USB_MOUNT_POINT"; then
        log_message "USB mounted successfully"
        
        if [ -d "$OPENWRT_PATH" ]; then
            log_message "OpenWRT directory found"
            cd "$OPENWRT_PATH"
            chmod +x start.cmd config/*.cfg 2>/dev/null || true
            sed -i 's/\r$//' start.cmd config/*.cfg 2>/dev/null || true
            log_message "Starting OpenWRT configuration..."
            ./start.cmd
        else
            log_message "ERROR: OpenWRT directory not found"
            ls -la "$USB_MOUNT_POINT"
        fi
    else
        log_message "ERROR: Failed to mount USB"
    fi
else
    log_message "ERROR: No USB device detected"
fi
