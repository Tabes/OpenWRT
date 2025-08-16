#!/bin/ash
### BPI-R4 OpenWRT Configuration Master Script ###
### Executes all Configuration Files in Sequence ###
### Usage: ./start.cfg [-YES] ###

### === GLOBAL CONFIGURATION === ###
. /root/openWRT/config/global.cfg

### === PATH CONFIGURATION === ###
SCRIPT_DIR="$(dirname "$0")"
CONFIG_DIR="${SCRIPT_DIR}"

### === SCRIPT VARIABLES === ###
SCRIPT_NAME="$(basename "$0" .cfg)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_PATH/${SCRIPT_NAME}_${TIMESTAMP}.log"
ERROR_LOG="$LOG_PATH/${SCRIPT_NAME}_errors_${TIMESTAMP}.log"
AUTO_EXECUTE=false

### === CONFIGURATION FILE LIST === ###
### Add or remove files here as needed ###
CONFIG_FILES="
prepare.cfg
interface.cfg
network.cfg
wifi.cfg
firewall.cfg
router.cfg
upgrade.cfg
"

set -e  ### Exit on any error ###

### === PARAMETER HANDLING === ###
for param in "$@"; do
    case "$param" in
        "-YES"|"-yes"|"--yes")
            AUTO_EXECUTE=true
            ;;
        "-h"|"--help")
            echo "Usage: $0 [-YES]"
            echo "  -YES    Execute all configuration files without prompts"
            echo "  -h      Show this help"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $param"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

### === CREATE DIRECTORIES === ###
mkdir -p "$LOG_PATH"
mkdir -p "$BACKUP_PATH"
mkdir -p "$HELPER_PATH"

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

ask_user_confirmation() {
    CONFIG_NAME="$1"
    
    if [ "$AUTO_EXECUTE" = true ]; then
        log_message "AUTO-EXECUTE: Processing $CONFIG_NAME"
        return 0
    fi
    
    echo ""
    echo "Execute configuration file: $CONFIG_NAME"
    echo "Options:"
    echo "  [y] Yes, execute this file"
    echo "  [n] No, skip this file"
    echo "  [a] Yes to all (auto-execute remaining files)"
    echo "  [q] Quit configuration process"
    read -p "Choice [y/n/a/q]: " CHOICE
    
    case "$CHOICE" in
        "y"|"Y")
            return 0
            ;;
        "a"|"A")
            AUTO_EXECUTE=true
            log_message "AUTO-EXECUTE enabled for remaining files"
            return 0
            ;;
        "q"|"Q")
            log_message "Configuration process aborted by user"
            exit 0
            ;;
        *)
            log_message "Skipping $CONFIG_NAME"
            return 1
            ;;
    esac
}

execute_config_file() {
    CONFIG_FILE="$1"
    CONFIG_NAME=$(basename "$CONFIG_FILE")
    FULL_PATH="${CONFIG_DIR}/${CONFIG_FILE}"
    
    log_separator
    log_message "Processing configuration file: $CONFIG_NAME"
    
    ### Check if file exists ###
    if [ ! -f "$FULL_PATH" ]; then
        log_message "WARNING: $CONFIG_NAME not found at $FULL_PATH"
        log_message "Skipping missing file..."
        echo ""
        return 0
    fi
    
    ### Ask user confirmation ###
    if ! ask_user_confirmation "$CONFIG_NAME"; then
        echo ""
        return 0
    fi
    
    ### Make file executable ###
    chmod +x "$FULL_PATH" 2>/dev/null || {
        log_message "WARNING: Could not make $CONFIG_NAME executable"
    }
    
    ### Log file information ###
    FILE_SIZE=$(stat -c%s "$FULL_PATH" 2>/dev/null || echo "unknown")
    log_message "File path: $FULL_PATH"
    log_message "File size: $FILE_SIZE bytes"
    
    ### Execute configuration file ###
    log_command "$FULL_PATH"
    echo ""
    
    ### Source global.cfg in subshell for each config file ###
    if (. "$CONFIG_DIR/global.cfg" && sh "$FULL_PATH") 2>&1 | tee -a "$LOG_FILE"; then
        EXEC_STATUS=0
        log_message "SUCCESS: $CONFIG_NAME completed successfully"
    else
        EXEC_STATUS=$?
        log_message "ERROR: $CONFIG_NAME failed with exit code: $EXEC_STATUS"
        echo "ERROR in $CONFIG_NAME (Exit Code: $EXEC_STATUS)" >> "$ERROR_LOG"
        
        ### Handle execution error ###
        if [ "$AUTO_EXECUTE" = false ]; then
            echo ""
            echo "Configuration error occurred in $CONFIG_NAME"
            echo "Options:"
            echo "  [c] Continue with next configuration file"
            echo "  [r] Retry current configuration file"
            echo "  [a] Abort entire configuration process"
            read -p "Choice [c/r/a]: " ERROR_CHOICE
            
            case "$ERROR_CHOICE" in
                "r"|"R")
                    log_message "Retrying $CONFIG_NAME..."
                    if (. "$CONFIG_DIR/global.cfg" && sh "$FULL_PATH") 2>&1 | tee -a "$LOG_FILE"; then
                        log_message "SUCCESS: $CONFIG_NAME completed on retry"
                        EXEC_STATUS=0
                    else
                        log_message "ERROR: $CONFIG_NAME failed again"
                        echo "ERROR in $CONFIG_NAME (Retry Failed)" >> "$ERROR_LOG"
                    fi
                    ;;
                "a"|"A")
                    log_message "Configuration process aborted by user due to error"
                    exit 1
                    ;;
                *)
                    log_message "Continuing with next configuration file..."
                    ;;
            esac
        else
            log_message "AUTO-EXECUTE: Continuing despite error in $CONFIG_NAME"
        fi
    fi
    
    ### Add completion marker ###
    echo "" | tee -a "$LOG_FILE"
    echo "--- End of $CONFIG_NAME (Status: $EXEC_STATUS) ---" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    ### Wait between configurations ###
    if [ "$AUTO_EXECUTE" = false ]; then
        echo "Press [Enter] to continue or [Ctrl+C] to abort..."
        read CONTINUE
    else
        sleep 2
    fi
}

### === SCRIPT HEADER === ###
clear
log_separator
log_message "BPI-R4 OpenWRT Configuration Master Script Started"
log_message "Config Version: $CONFIG_VERSION ($CONFIG_DATE)"
log_message "Router Hostname: $ROUTER_HOSTNAME"
log_message "Script Directory: $SCRIPT_DIR"
log_message "Config Directory: $CONFIG_DIR"
log_message "Log File: $LOG_FILE"
log_message "Error Log: $ERROR_LOG"
log_message "Auto Execute: $AUTO_EXECUTE"
log_separator

### === ENVIRONMENT CHECK === ###
log_message "Checking environment..."

### Check if running as root ###
if [ "$(id -u)" != "0" ]; then
    log_message "ERROR: This script must be run as root"
    exit 1
fi

### Check if config directory exists ###
if [ ! -d "$CONFIG_DIR" ]; then
    log_message "ERROR: Config directory not found: $CONFIG_DIR"
    exit 1
fi

### Check if global.cfg exists ###
if [ ! -f "$CONFIG_DIR/global.cfg" ]; then
    log_message "ERROR: Global configuration file not found: $CONFIG_DIR/global.cfg"
    exit 1
fi

### Display configuration variables ###
log_message "Configuration Variables:"
echo "  Router: $ROUTER_HOSTNAME (Country: $COUNTRY_CODE)" | tee -a "$LOG_FILE"
echo "  LAN1: $LAN1_SUBNET ($LAN1_IP)" | tee -a "$LOG_FILE"
echo "  LAN2: $LAN2_SUBNET ($LAN2_IP)" | tee -a "$LOG_FILE"
echo "  LAN3: $LAN3_SUBNET ($LAN3_IP)" | tee -a "$LOG_FILE"
echo "  Guest: $GUEST_SUBNET ($GUEST_IP)" | tee -a "$LOG_FILE"
echo "  WiFi SSID: $MAIN_SSID" | tee -a "$LOG_FILE"
echo "  Guest SSID: $GUEST_SSID" | tee -a "$LOG_FILE"

echo ""

### Display available configuration files ###
log_message "Available configuration files:"
for config_file in $CONFIG_FILES; do
    config_file=$(echo "$config_file" | tr -d ' \t\n\r')
    if [ -n "$config_file" ]; then
        FULL_PATH="${CONFIG_DIR}/${config_file}"
        if [ -f "$FULL_PATH" ]; then
            FILE_SIZE=$(stat -c%s "$FULL_PATH" 2>/dev/null || echo "?")
            echo "  ✓ $config_file ($FILE_SIZE bytes)" | tee -a "$LOG_FILE"
        else
            echo "  ✗ $config_file (missing)" | tee -a "$LOG_FILE"
        fi
    fi
done

echo ""

### Confirm execution start ###
if [ "$AUTO_EXECUTE" = false ]; then
    echo "Ready to start configuration process"
    read -p "Continue? [y/N]: " START_CONFIRM
    
    case "$START_CONFIRM" in
        "y"|"Y")
            log_message "Configuration process started by user"
            ;;
        *)
            log_message "Configuration process cancelled by user"
            exit 0
            ;;
    esac
else
    log_message "AUTO-EXECUTE: Starting configuration process automatically"
fi

### === EXECUTE CONFIGURATION FILES === ###
log_separator
log_message "Starting configuration file execution sequence..."

for config_file in $CONFIG_FILES; do
    ### Remove whitespace ###
    config_file=$(echo "$config_file" | tr -d ' \t\n\r')
    
    ### Skip empty lines ###
    if [ -n "$config_file" ]; then
        execute_config_file "$config_file"
    fi
done

### === FINAL SYSTEM STATUS === ###
log_separator
log_message "Configuration execution completed"
log_separator

log_message "Gathering final system status..."

### Network interfaces ###
log_message "Network Interfaces:"
ip addr show | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"

### UCI configuration ###
log_message "UCI Network Configuration:"
uci show network 2>/dev/null | tee -a "$LOG_FILE" || log_message "No network config available"

echo "" | tee -a "$LOG_FILE"

### UCI DHCP configuration ###
log_message "UCI DHCP Configuration:"
uci show dhcp 2>/dev/null | tee -a "$LOG_FILE" || log_message "No DHCP config available"

echo "" | tee -a "$LOG_FILE"

### Wireless devices ###
log_message "Wireless Devices:"
iw dev 2>/dev/null | tee -a "$LOG_FILE" || log_message "No wireless devices found"

echo "" | tee -a "$LOG_FILE"

### USB devices (for 5G modem) ###
log_message "USB Devices:"
lsusb 2>/dev/null | tee -a "$LOG_FILE" || log_message "lsusb not available"

### === EXECUTION SUMMARY === ###
log_separator
log_message "Configuration Execution Summary"
log_separator

if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
    log_message "ERRORS OCCURRED during configuration:"
    cat "$ERROR_LOG" | tee -a "$LOG_FILE"
    echo ""
    OVERALL_STATUS="COMPLETED WITH ERRORS"
else
    log_message "SUCCESS: All configurations executed successfully"
    OVERALL_STATUS="COMPLETED SUCCESSFULLY"
fi

log_message "Configuration logs saved to: $LOG_FILE"

if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
    log_message "Error log saved to: $ERROR_LOG"
fi

log_message "Overall Status: $OVERALL_STATUS"

log_message "Helper scripts available:"
log_message "  $HELPER_PATH/network_status.sh - Show network status"
log_message "  $HELPER_PATH/wifi_scan.sh - Scan for WiFi networks"
log_message "  $HELPER_PATH/modem_test.sh - Test 5G modem"
log_message "  $HELPER_PATH/network_test.sh - Test network connectivity"

log_message "Recommended next steps:"
log_message "1. Review configuration logs for any issues"
log_message "2. Test network connectivity: $HELPER_PATH/network_test.sh"
log_message "3. Restart network services: /etc/init.d/network restart"
log_message "4. Reboot system for complete activation: reboot"
log_message "5. Access web interface: http://$LAN1_IP"

log_separator
log_message "BPI-R4 OpenWRT Configuration Process Completed"
log_separator

### === OPTIONAL REBOOT === ###
if [ "$AUTO_EXECUTE" = false ]; then
    echo ""
    echo "Configuration process completed!"
    echo "Status: $OVERALL_STATUS"
    read -p "Reboot system now to activate all changes? (y/N): " REBOOT_CHOICE
    
    if [ "$REBOOT_CHOICE" = "y" ] || [ "$REBOOT_CHOICE" = "Y" ]; then
        log_message "System reboot initiated by user"
        sync
        sleep 2
        reboot
    else
        log_message "System reboot skipped by user"
        echo "Manual reboot recommended: reboot"
    fi
else
    log_message "AUTO-EXECUTE: Configuration completed, reboot recommended"
    echo "Manual reboot recommended: reboot"
fi