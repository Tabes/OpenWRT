#!/bin/ash
### BPI-R4 OpenWRT Master Configuration Script ###
### Executes all configuration files in sequence ###
### Execute from USB: /mnt/usb/root/start.cmd ###

set -e  ### Exit on any error ###

### === SCRIPT CONFIGURATION === ###
SCRIPT_DIR="$(dirname "$0")"
CONFIG_DIR="${SCRIPT_DIR}/config"
LOG_FILE="/tmp/openwrt_install_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="/tmp/openwrt_errors_$(date +%Y%m%d_%H%M%S).log"

### === LOGGING FUNCTIONS === ###
log_message() {
    local MESSAGE="$1"
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] $MESSAGE" | tee -a "$LOG_FILE"
    echo ""
}

log_command() {
    local COMMAND="$1"
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] EXECUTING: $COMMAND" | tee -a "$LOG_FILE"
}

log_separator() {
    echo "========================================" | tee -a "$LOG_FILE"
}

### === SCRIPT HEADER === ###
clear
log_separator
log_message "BPI-R4 OpenWRT Configuration Started"
log_message "Script Directory: $SCRIPT_DIR"
log_message "Config Directory: $CONFIG_DIR"
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
if [ ! -d "$CONFIG_DIR" ]; then
    log_message "ERROR: Config directory not found: $CONFIG_DIR"
    log_message "Expected USB structure: /mnt/usb/root/config/"
    exit 1
fi

# List available config files
log_message "Available configuration files:"
ls -la "$CONFIG_DIR"/*.cfg 2>/dev/null | tee -a "$LOG_FILE" || {
    log_message "WARNING: No .cfg files found in $CONFIG_DIR"
}

echo ""

### === EXECUTION SEQUENCE === ###
EXECUTION_ORDER=(
    "prepare.cfg"
    "interface.cfg" 
    "network.cfg"
    "upgrade.cfg"
)

log_message "Starting configuration sequence..."
log_separator

### === EXECUTE CONFIGURATION FILES === ###
for CONFIG_FILE in "${EXECUTION_ORDER[@]}"; do
    FULL_PATH="${CONFIG_DIR}/${CONFIG_FILE}"
    
    log_separator
    log_message "Processing: $CONFIG_FILE"
    
    # Check if file exists
    if [ ! -f "$FULL_PATH" ]; then
        log_message "WARNING: $CONFIG_FILE not found, skipping..."
        echo ""
        continue
    fi
    
    # Make file executable
    chmod +x "$FULL_PATH"
    
    # Log file info
    log_message "File size: $(stat -c%s "$FULL_PATH") bytes"
    log_message "File permissions: $(stat -c%A "$FULL_PATH")"
    
    # Execute with error handling
    log_command "$FULL_PATH"
    
    if "$FULL_PATH" 2>&1 | tee -a "$LOG_FILE"; then
        log_message "SUCCESS: $CONFIG_FILE completed successfully"
        
        # Add separator after each script
        echo "" | tee -a "$LOG_FILE"
        echo "--- End of $CONFIG_FILE ---" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    else
        EXIT_CODE=$?
        log_message "ERROR: $CONFIG_FILE failed with exit code: $EXIT_CODE"
        echo "ERROR in $CONFIG_FILE (Exit Code: $EXIT_CODE)" >> "$ERROR_LOG"
        
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
                log_message "Retrying $CONFIG_FILE..."
                if "$FULL_PATH" 2>&1 | tee -a "$LOG_FILE"; then
                    log_message "SUCCESS: $CONFIG_FILE completed on retry"
                else
                    log_message "ERROR: $CONFIG_FILE failed again, continuing..."
                fi
                ;;
            *)
                log_message "Continuing with next script..."
                ;;
        esac
    fi
    
    # Wait a moment between scripts
    sleep 2
done

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