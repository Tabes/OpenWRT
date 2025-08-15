#!/bin/ash
### BPI-R4 OpenWRT Master Configuration Script ###
### Executes all Configuration Files in Sequence ###
### Execute from USB: /mnt/usb/OpenWRT/start.cmd ###


### USB mounten                                 ###
### mkdir -p /mnt/usb                           ###
### mount /dev/sda1 /mnt/usb                    ###

### Script ausführbar machen                    ###
### chmod +x /mnt/usb/OpenWRT/start.cmd         ###

### Windows-Zeilenendings entfernen
### sed -i 's/\r$//' /mnt/usb/OpenWRT/start     ###

### Script starten                              ###
### cd /mnt/usb/OpenWRT                         ###
### ./start.cmd                                 ###


### === PATH CONFIGURATION === ###
USB_BASE_PATH="/mnt/usb/OpenWRT"
CONFIG_PATH="${USB_BASE_PATH}/config"

### === SCRIPT VARIABLES === ###
LOG_FILE="/tmp/openwrt_install_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="/tmp/openwrt_errors_$(date +%Y%m%d_%H%M%S).log"

### === CONFIGURATION FILES ORDER === ###
PREPARE_CFG="${CONFIG_PATH}/prepare.cfg"
INTERFACE_CFG="${CONFIG_PATH}/interface.cfg"
NETWORK_CFG="${CONFIG_PATH}/network.cfg"
UPDATE_CFG="${CONFIG_PATH}/update.cfg"

set -e  ### Exit on any error ###

### === LOGGING FUNCTIONS === ###
log_message() {
    MESSAGE="$1"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] $MESSAGE" | tee -a "$LOG_FILE"
    echo ""
}

log_command() {
    COMMAND="$1"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] EXECUTING: $COMMAND" | tee -a "$LOG_FILE"
}

log_separator() {
    echo "================================================================================" | tee -a "$LOG_FILE"
}

execute_config() {
    CONFIG_FILE="$1"
    CONFIG_NAME=$(basename "$CONFIG_FILE")
    
    log_separator
    log_message "Processing: $CONFIG_NAME"
    
    # Check if file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "WARNING: $CONFIG_NAME not found, skipping..."
        echo ""
        return 0
    fi
    
    # Make file executable
    chmod +x "$CONFIG_FILE"
    
    # Log file info
    FILE_SIZE=$(stat -c%s "$CONFIG_FILE" 2>/dev/null || echo "unknown")
    log_message "File size: $FILE_SIZE bytes"
    
    # Execute with error handling
    log_command "$CONFIG_FILE"
    
    if sh "$CONFIG_FILE" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "SUCCESS: $CONFIG_NAME completed successfully"
        
        # Add separator after each script
        echo "" | tee -a "$LOG_FILE"
        echo "--- End of $CONFIG_NAME ---" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        return 0
    else
        EXIT_CODE=$?
        log_message "ERROR: $CONFIG_NAME failed with exit code: $EXIT_CODE"
        echo "ERROR in $CONFIG_NAME (Exit Code: $EXIT_CODE)" >> "$ERROR_LOG"
        
        # Ask user if they want to continue
        echo ""
        echo "Configuration error occurred. Options:"
        echo "1) Continue with next script (c)"
        echo "2) Abort installation (a)"
        echo "3) Retry current script (r)"
        read -p "Choice [c/a/r]: " CHOICE
        
        case "$CHOICE" in
            "a"|"A")
                log_message "Installation aborted by user"
                exit 1
                ;;
            "r"|"R")
                log_message "Retrying $CONFIG_NAME..."
                if sh "$CONFIG_FILE" 2>&1 | tee -a "$LOG_FILE"; then
                    log_message "SUCCESS: $CONFIG_NAME completed on retry"
                    return 0
                else
                    log_message "ERROR: $CONFIG_NAME failed again, continuing..."
                    return 1
                fi
                ;;
            *)
                log_message "Continuing with next script..."
                return 1
                ;;
        esac
    fi
}

### === SCRIPT HEADER === ###
clear
log_separator
log_message "BPI-R4 OpenWRT Configuration Started"
log_message "USB Base Path: $USB_BASE_PATH"
log_message "Config Path: $CONFIG_PATH"
log_message "Log File: $LOG_FILE"
log_message "Error Log: $ERROR_LOG"
log_separator

### === ENVIRONMENT CHECK === ###
log_message "Checking environment..."

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    log_message "ERROR: This script must be run as root"
    exit 1
fi

# Check if config directory exists
if [ ! -d "$CONFIG_PATH" ]; then
    log_message "ERROR: Config directory not found: $CONFIG_PATH"
    log_message "Expected USB structure: $USB_BASE_PATH/config/"
    exit 1
fi

# List available config files
log_message "Available configuration files:"
ls -la "$CONFIG_PATH"/*.cfg 2>/dev/null | tee -a "$LOG_FILE" || {
    log_message "WARNING: No .cfg files found in $CONFIG_PATH"
}

echo ""

### === EXECUTE CONFIGURATION FILES === ###
log_message "Starting configuration sequence..."
log_separator

# Execute in order
execute_config "$PREPARE_CFG"
sleep 2

execute_config "$INTERFACE_CFG"
sleep 2

execute_config "$NETWORK_CFG"
sleep 2

execute_config "$UPDATE_CFG"
sleep 2

### === FINAL SYSTEM STATUS === ###
log_separator
log_message "Configuration sequence completed"
log_separator

log_message "Gathering system status..."

# Network interfaces
log_message "Network Interfaces:"
ip addr show | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"

# UCI network config
log_message "UCI Network Configuration:"
uci show network 2>/dev/null | tee -a "$LOG_FILE" || log_message "No network config found"

echo "" | tee -a "$LOG_FILE"

# Available wireless devices
log_message "Wireless Devices:"
iw dev 2>/dev/null | tee -a "$LOG_FILE" || log_message "No wireless devices found"

echo "" | tee -a "$LOG_FILE"

# USB devices (for 5G modem)
log_message "USB Devices:"
lsusb 2>/dev/null | tee -a "$LOG_FILE" || log_message "lsusb not available"

### === CLEANUP AND RECOMMENDATIONS === ###
log_separator
log_message "Installation Summary"
log_separator

if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
    log_message "ERRORS OCCURRED during installation:"
    cat "$ERROR_LOG" | tee -a "$LOG_FILE"
    echo ""
fi

log_message "Configuration logs saved to: $LOG_FILE"

if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
    log_message "Error log saved to: $ERROR_LOG"
fi

log_message "Next steps:"
log_message "1. Review logs for any errors"
log_message "2. Restart network: /etc/init.d/network restart"
log_message "3. Reboot system: reboot"
log_message "4. Access web interface: http://192.168.1.1"

log_separator
log_message "BPI-R4 OpenWRT Configuration Completed"
log_separator

### === OPTIONAL REBOOT === ###
echo ""
echo "Configuration completed!"
read -p "Reboot system now? (y/N): " REBOOT_CHOICE

if [ "$REBOOT_CHOICE" = "y" ] || [ "$REBOOT_CHOICE" = "Y" ]; then
    log_message "System reboot initiated by user"
    sync
    reboot
else
    log_message "System reboot skipped by user"
    echo "Manual reboot recommended: reboot"
fi