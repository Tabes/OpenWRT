#!/bin/ash
### BPI-R4 OpenWRT USB-to-System Copy Script ###
### Copies all files from USB Stick to /root/openWRT ###
### Execute from USB: /mnt/usb/OpenWRT/start.cmd ###


### USB mounten                                     ###
### mkdir -p /mnt/usb                               ###
### mount /dev/sda1 /mnt/usb                        ###

### Script ausführbar machen                        ###
### chmod +x /mnt/usb/OpenWRT/start.cmd             ###

### Windows-Zeilenendings entfernen
### sed -i 's/\r$//' /mnt/usb/OpenWRT/start.cmd     ###

### Script starten                                  ###
### cd /mnt/usb/OpenWRT                             ###
### ./start.cmd                                     ###


### === LOAD GLOBAL CONFIGURATION === ###
GLOBAL_CONFIG="/root/openWRT/global.cfg"
if [ ! -f "$GLOBAL_CONFIG" ]; then
    echo "ERROR: Global configuration file not found: $GLOBAL_CONFIG"
    echo "Please ensure global.cfg exists before running this script."
    exit 1
fi

### Load global configuration ###
. "$GLOBAL_CONFIG"

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

### === SCRIPT HEADER === ###
clear
log_separator
log_message "BPI-R4 OpenWRT USB-to-System copy operation started"
log_message "USB Source Path: $USB_BASE_PATH"
log_message "Target Path: $TARGET_BASE_PATH"
log_message "Helper Path: $HELPER_PATH"
log_message "Log Path: $LOG_PATH"
log_message "Log File: $LOG_FILE"
log_message "Error Log: $ERROR_LOG"
log_separator

### === ENVIRONMENT CHECK === ###
log_message "Checking environment..."

### Check if running as root ###
if [ "$(id -u)" != "0" ]; then
    log_message "ERROR: This script must be run as root"
    exit 1
fi

### Check if USB source exists ###
if [ ! -d "$USB_BASE_PATH" ]; then
    log_message "ERROR: USB source directory not found: $USB_BASE_PATH"
    log_message "Please mount USB stick first:"
    log_message "  mkdir -p /mnt/usb"
    log_message "  mount /dev/sda1 /mnt/usb"
    exit 1
fi

### Check if config source exists ###
if [ ! -d "$CONFIG_SOURCE_PATH" ]; then
    log_message "ERROR: Config source directory not found: $CONFIG_SOURCE_PATH"
    log_message "Expected USB structure: $USB_BASE_PATH/config/"
    exit 1
fi

### === CREATE TARGET DIRECTORIES === ###
log_message "Creating target directories..."

log_command "mkdir -p $TARGET_BASE_PATH"
mkdir -p "$TARGET_BASE_PATH" || {
    log_message "ERROR: Cannot create target directory: $TARGET_BASE_PATH"
    exit 1
}

log_command "mkdir -p $CONFIG_TARGET_PATH"
mkdir -p "$CONFIG_TARGET_PATH" || {
    log_message "ERROR: Cannot create config directory: $CONFIG_TARGET_PATH"
    exit 1
}

log_command "mkdir -p $HELPER_PATH"
mkdir -p "$HELPER_PATH" || {
    log_message "ERROR: Cannot create helper directory: $HELPER_PATH"
    exit 1
}

log_command "mkdir -p $LOG_PATH"
mkdir -p "$LOG_PATH" || {
    log_message "ERROR: Cannot create log directory: $LOG_PATH"
    exit 1
}

log_command "mkdir -p $HELPER_PATH"
mkdir -p "$HELPER_PATH" || {
    log_message "ERROR: Cannot create helper directory: $HELPER_PATH"
    exit 1
}

log_command "mkdir -p $LOG_PATH"
mkdir -p "$LOG_PATH" || {
    log_message "ERROR: Cannot create log directory: $LOG_PATH"
    exit 1
}

### === BACKUP EXISTING CONFIGURATION === ###
if [ -d "$TARGET_BASE_PATH" ] && [ "$(ls -A $TARGET_BASE_PATH 2>/dev/null)" ]; then
    log_message "Existing configuration found, creating backup..."
    BACKUP_DIR="/root/backup/openWRT_$(date +%Y%m%d_%H%M%S)"
    log_command "mkdir -p $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    log_command "cp -r $TARGET_BASE_PATH/* $BACKUP_DIR/"
    cp -r "$TARGET_BASE_PATH"/* "$BACKUP_DIR/" 2>/dev/null || true
    log_message "Backup saved to: $BACKUP_DIR"
fi

### === COPY CONFIG FILES FROM USB === ###
log_separator
log_message "Copying configuration files from USB..."

### List available files on USB ###
log_message "Available files on USB:"
ls -la "$CONFIG_SOURCE_PATH"/ | tee -a "$LOG_FILE" 2>/dev/null || {
    log_message "WARNING: Cannot list files in $CONFIG_SOURCE_PATH"
}

echo ""

### Copy all .cfg files ###
log_message "Copying .cfg files..."
for cfg_file in "$CONFIG_SOURCE_PATH"/*.cfg; do
    if [ -f "$cfg_file" ]; then
        FILE_NAME=$(basename "$cfg_file")
        log_command "cp $cfg_file $CONFIG_TARGET_PATH/$FILE_NAME"
        
        if cp "$cfg_file" "$CONFIG_TARGET_PATH/$FILE_NAME" 2>/dev/null; then
            log_message "SUCCESS: Copied $FILE_NAME"
        else
            log_message "ERROR: Failed to copy $FILE_NAME"
            echo "ERROR copying $FILE_NAME" >> "$ERROR_LOG"
        fi
    fi
done

### Copy start.cmd from config directory if exists ###
if [ -f "$CONFIG_SOURCE_PATH/start.cmd" ]; then
    log_command "cp $CONFIG_SOURCE_PATH/start.cmd $CONFIG_TARGET_PATH/start.cmd"
    
    if cp "$CONFIG_SOURCE_PATH/start.cmd" "$CONFIG_TARGET_PATH/start.cmd" 2>/dev/null; then
        log_message "SUCCESS: Copied config/start.cmd"
    else
        log_message "ERROR: Failed to copy config/start.cmd"
        echo "ERROR copying config/start.cmd" >> "$ERROR_LOG"
    fi
fi

### Move start.cmd from config to root directory ###
if [ -f "$CONFIG_TARGET_PATH/start.cmd" ]; then
    log_command "mv $CONFIG_TARGET_PATH/start.cmd $TARGET_BASE_PATH/start.cmd"
    
    if mv "$CONFIG_TARGET_PATH/start.cmd" "$TARGET_BASE_PATH/start.cmd" 2>/dev/null; then
        log_message "SUCCESS: Moved start.cmd to root directory"
    else
        log_message "ERROR: Failed to move start.cmd to root directory"
        echo "ERROR moving start.cmd to root" >> "$ERROR_LOG"
    fi
fi

### === MAKE FILES EXECUTABLE === ###
log_separator
log_message "Making files executable..."

### Make all .cfg files executable ###
for cfg_file in "$CONFIG_TARGET_PATH"/*.cfg; do
    if [ -f "$cfg_file" ]; then
        FILE_NAME=$(basename "$cfg_file")
        log_command "chmod +x $cfg_file"
        
        if chmod +x "$cfg_file" 2>/dev/null; then
            log_message "SUCCESS: Made $FILE_NAME executable"
        else
            log_message "WARNING: Could not make $FILE_NAME executable"
        fi
    fi
done

### Make start.cmd executable ###
if [ -f "$TARGET_BASE_PATH/start.cmd" ]; then
    log_command "chmod +x $TARGET_BASE_PATH/start.cmd"
    
    if chmod +x "$TARGET_BASE_PATH/start.cmd" 2>/dev/null; then
        log_message "SUCCESS: Made start.cmd executable"
    else
        log_message "WARNING: Could not make start.cmd executable"
    fi
fi

### === REMOVE WINDOWS LINE ENDINGS === ###
log_separator
log_message "Removing Windows line endings..."

### Process all .cfg files ###
for cfg_file in "$CONFIG_TARGET_PATH"/*.cfg; do
    if [ -f "$cfg_file" ]; then
        FILE_NAME=$(basename "$cfg_file")
        log_command "sed -i 's/\r$//' $cfg_file"
        
        if sed -i 's/\r$//' "$cfg_file" 2>/dev/null; then
            log_message "SUCCESS: Cleaned line endings in $FILE_NAME"
        else
            log_message "WARNING: Could not clean line endings in $FILE_NAME"
        fi
    fi
done

### Process start.cmd ###
if [ -f "$TARGET_BASE_PATH/start.cmd" ]; then
    log_command "sed -i 's/\r$//' $TARGET_BASE_PATH/start.cmd"
    
    if sed -i 's/\r$//' "$TARGET_BASE_PATH/start.cmd" 2>/dev/null; then
        log_message "SUCCESS: Cleaned line endings in start.cmd"
    else
        log_message "WARNING: Could not clean line endings in start.cmd"
    fi
fi

### === VERIFY COPIED FILES === ###
log_separator
log_message "Verifying copied files..."

log_message "Files in target directory:"
ls -la "$TARGET_BASE_PATH"/ | tee -a "$LOG_FILE" 2>/dev/null || {
    log_message "WARNING: Cannot list target directory"
}

echo ""

log_message "Files in config directory:"
ls -la "$CONFIG_TARGET_PATH"/ | tee -a "$LOG_FILE" 2>/dev/null || {
    log_message "WARNING: Cannot list config directory"
}

### === INSTALLATION SUMMARY === ###
log_separator
log_message "Copy Operation Summary"
log_separator

if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
    log_message "ERRORS OCCURRED during copy operation:"
    cat "$ERROR_LOG" | tee -a "$LOG_FILE"
    echo ""
else
    log_message "SUCCESS: All files copied successfully"
fi

log_message "Copy operation logs saved to: $LOG_FILE"

if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
    log_message "Error log saved to: $ERROR_LOG"
fi

log_message "Next steps:"
log_message "1. Change to target directory: cd $TARGET_BASE_PATH"
log_message "2. Execute configuration: ./start.cmd"
log_message "3. Review logs for any errors"

log_separator
log_message "Files successfully copied from USB to system"
log_message "Ready for configuration execution"
log_separator

### === OPTIONAL EXECUTION === ###
echo ""
echo "Copy operation completed!"
read -p "Execute configuration now? (y/N): " EXEC_CHOICE

if [ "$EXEC_CHOICE" = "y" ] || [ "$EXEC_CHOICE" = "Y" ]; then
    log_message "Starting configuration execution..."
    
    if [ -f "$TARGET_BASE_PATH/start.cmd" ]; then
        cd "$TARGET_BASE_PATH"
        log_command "./start.cmd"
        ./start.cmd
    else
        log_message "ERROR: start.cmd not found in target directory"
        exit 1
    fi
else
    log_message "Configuration execution skipped by user"
    echo "Manual execution: cd $TARGET_BASE_PATH && ./start.cmd"
fi
