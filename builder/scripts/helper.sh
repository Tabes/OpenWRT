#!/bin/bash
################################################################################
### OpenWRT Custom Builder - Common Helper Functions
### Shared utility functions for all builder scripts
################################################################################
### Project: OpenWRT Custom Builder
### Version: 1.0.0
### Author:  OpenWRT Builder Team
### Date:    2025-08-19
### License: MIT
################################################################################

### Prevent multiple inclusion ###
if [ -n "$HELPER_FUNCTIONS_LOADED" ]; then
    return 0
fi
HELPER_FUNCTIONS_LOADED=1

################################################################################
### GLOBAL VARIABLES AND CONSTANTS
################################################################################

### Colors for output ###
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export BOLD='\033[1m'
export DIM='\033[2m'
export NC='\033[0m'

### Unicode symbols ###
export SYMBOL_SUCCESS="✅"
export SYMBOL_ERROR="❌"
export SYMBOL_WARNING="⚠️"
export SYMBOL_INFO="ℹ️"
export SYMBOL_ARROW="➤"
export SYMBOL_BULLET="•"
export SYMBOL_CHECK="✓"
export SYMBOL_CROSS="✗"

### Log levels ###
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARNING=2
export LOG_LEVEL_ERROR=3

### Default settings ###
export DEFAULT_LOG_LEVEL=$LOG_LEVEL_INFO
export DEFAULT_LOG_FILE="/tmp/builder.log"
export DEFAULT_QUIET_MODE=false
export DEFAULT_VERBOSE_MODE=false

################################################################################
### BASIC OUTPUT FUNCTIONS
################################################################################

### Print colored message ###
print_msg() {
    local color=$1
    shift
    if [ "$DEFAULT_QUIET_MODE" != "true" ]; then
        echo -e "${color}$*${NC}"
    fi
}

### Print without color (for logging) ###
print_plain() {
    echo "$*"
}

### Print with timestamp ###
print_timestamped() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*"
}

################################################################################
### HEADER AND FORMATTING FUNCTIONS
################################################################################

### Print main header ###
print_header() {
    if [ "$DEFAULT_QUIET_MODE" != "true" ]; then
        echo ""
        print_msg "$BLUE" "################################################################################"
        print_msg "$BLUE" "### $1"
        print_msg "$BLUE" "################################################################################"
        echo ""
    fi
}

### Print sub-header ###
print_subheader() {
    if [ "$DEFAULT_QUIET_MODE" != "true" ]; then
        echo ""
        print_msg "$CYAN" "-----------------------------------------------------------------------------"
        print_msg "$CYAN" "  $1"
        print_msg "$CYAN" "-----------------------------------------------------------------------------"
    fi
}

### Print section ###
print_section() {
    if [ "$DEFAULT_QUIET_MODE" != "true" ]; then
        echo ""
        print_msg "$WHITE" "=== $1 ==="
        echo ""
    fi
}

### Print step ###
print_step() {
    local step_num=$1
    shift
    if [ "$DEFAULT_QUIET_MODE" != "true" ]; then
        print_msg "$GREEN" "${step_num}. $*"
    fi
}

### Print box with content ###
print_box() {
    local title="$1"
    shift
    local content="$*"
    
    if [ "$DEFAULT_QUIET_MODE" != "true" ]; then
        local box_width=80
        local title_len=${#title}
        local padding=$(( (box_width - title_len - 4) / 2 ))
        
        echo ""
        print_msg "$BLUE" "$(printf '=%.0s' $(seq 1 $box_width))"
        print_msg "$BLUE" "$(printf '=%.0s' $(seq 1 $padding)) $title $(printf '=%.0s' $(seq 1 $padding))"
        print_msg "$BLUE" "$(printf '=%.0s' $(seq 1 $box_width))"
        print_msg "$WHITE" "$content"
        print_msg "$BLUE" "$(printf '=%.0s' $(seq 1 $box_width))"
        echo ""
    fi
}

################################################################################
### STATUS AND NOTIFICATION FUNCTIONS
################################################################################

### Print success message ###
print_success() {
    print_msg "$GREEN" "$SYMBOL_SUCCESS $*"
}

### Print error message ###
print_error() {
    print_msg "$RED" "$SYMBOL_ERROR $*" >&2
}

### Print warning message ###
print_warning() {
    print_msg "$YELLOW" "$SYMBOL_WARNING $*"
}

### Print info message ###
print_info() {
    print_msg "$CYAN" "$SYMBOL_INFO $*"
}

### Print bullet point ###
print_bullet() {
    local level=${1:-0}
    shift
    local indent=$(printf '  %.0s' $(seq 1 $level))
    print_msg "$CYAN" "${indent}$SYMBOL_BULLET $*"
}

### Print check item ###
print_check() {
    print_msg "$GREEN" "  $SYMBOL_CHECK $*"
}

### Print cross item ###
print_cross() {
    print_msg "$RED" "  $SYMBOL_CROSS $*"
}

### Print progress indicator ###
print_progress() {
    local current=$1
    local total=$2
    local description="$3"
    local percentage=$((current * 100 / total))
    
    if [ "$DEFAULT_QUIET_MODE" != "true" ]; then
        printf "\r${CYAN}Progress: [%3d%%] %s${NC}" "$percentage" "$description"
        if [ "$current" -eq "$total" ]; then
            echo ""
        fi
    fi
}

################################################################################
### LOGGING FUNCTIONS
################################################################################

### Initialize logging ###
init_logging() {
    local log_file="${1:-$DEFAULT_LOG_FILE}"
    local log_level="${2:-$DEFAULT_LOG_LEVEL}"
    
    export CURRENT_LOG_FILE="$log_file"
    export CURRENT_LOG_LEVEL="$log_level"
    
    ### Create log directory if needed ###
    local log_dir=$(dirname "$log_file")
    mkdir -p "$log_dir"
    
    ### Initialize log file ###
    {
        echo "################################################################################"
        echo "### Build Log Started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "### PID: $$"
        echo "### Script: ${0##*/}"
        echo "### Args: $*"
        echo "################################################################################"
    } > "$log_file"
}

### Log with level ###
log_message() {
    local level=$1
    local message="$2"
    local log_file="${CURRENT_LOG_FILE:-$DEFAULT_LOG_FILE}"
    
    ### Check if we should log this level ###
    if [ "$level" -ge "${CURRENT_LOG_LEVEL:-$DEFAULT_LOG_LEVEL}" ]; then
        local level_name=""
        case $level in
            $LOG_LEVEL_DEBUG)   level_name="DEBUG" ;;
            $LOG_LEVEL_INFO)    level_name="INFO" ;;
            $LOG_LEVEL_WARNING) level_name="WARNING" ;;
            $LOG_LEVEL_ERROR)   level_name="ERROR" ;;
            *)                  level_name="UNKNOWN" ;;
        esac
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$level_name] $message" >> "$log_file"
    fi
}

### Convenience logging functions ###
log_debug() {
    log_message $LOG_LEVEL_DEBUG "$*"
    [ "$DEFAULT_VERBOSE_MODE" = "true" ] && print_msg "$DIM" "DEBUG: $*"
}

log_info() {
    log_message $LOG_LEVEL_INFO "$*"
}

log_warning() {
    log_message $LOG_LEVEL_WARNING "$*"
    print_warning "$*"
}

log_error() {
    log_message $LOG_LEVEL_ERROR "$*"
    print_error "$*"
}

### Combined logging and display ###
log_print() {
    local color=$1
    local level=$2
    shift 2
    local message="$*"
    
    print_msg "$color" "$message"
    log_message "$level" "$message"
}

################################################################################
### ERROR HANDLING FUNCTIONS
################################################################################

### Error exit with cleanup ###
error_exit() {
    local exit_code="${2:-1}"
    log_error "$1"
    
    ### Call cleanup function if it exists ###
    if declare -f cleanup >/dev/null 2>&1; then
        cleanup
    fi
    
    exit "$exit_code"
}

### Check command success ###
check_command() {
    local command="$1"
    local error_message="$2"
    
    if ! eval "$command"; then
        error_exit "${error_message:-Command failed: $command}"
    fi
}

### Retry command with backoff ###
retry_command() {
    local max_attempts=${1:-3}
    local delay=${2:-5}
    shift 2
    local command="$*"
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warning "Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))  ### Exponential backoff ###
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 1
}

################################################################################
### VALIDATION FUNCTIONS
################################################################################

### Check if running as root ###
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (sudo)"
    fi
}

### Check if command exists ###
check_command_exists() {
    local command="$1"
    local package_hint="$2"
    
    if ! command -v "$command" >/dev/null 2>&1; then
        local message="Required command not found: $command"
        [ -n "$package_hint" ] && message="$message (try: apt install $package_hint)"
        error_exit "$message"
    fi
}

### Check required commands ###
check_required_commands() {
    local commands=("$@")
    local missing_commands=()
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        print_info "Please install missing dependencies"
        return 1
    fi
    
    return 0
}

### Check disk space ###
check_disk_space() {
    local path="$1"
    local required_gb="$2"
    
    local available_kb=$(df "$path" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        error_exit "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
    fi
    
    log_info "Disk space check passed: ${available_gb}GB available (${required_gb}GB required)"
}

### Validate directory ###
validate_directory() {
    local dir="$1"
    local create_if_missing="${2:-false}"
    
    if [ ! -d "$dir" ]; then
        if [ "$create_if_missing" = "true" ]; then
            mkdir -p "$dir" || error_exit "Cannot create directory: $dir"
            log_info "Created directory: $dir"
        else
            error_exit "Directory not found: $dir"
        fi
    fi
}

### Validate file ###
validate_file() {
    local file="$1"
    local required="${2:-true}"
    
    if [ ! -f "$file" ]; then
        if [ "$required" = "true" ]; then
            error_exit "Required file not found: $file"
        else
            return 1
        fi
    fi
    
    return 0
}

################################################################################
### UTILITY FUNCTIONS
################################################################################

### Convert bytes to human readable ###
bytes_to_human() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB" "PB")
    local unit=0
    
    while [ $bytes -gt 1024 ] && [ $unit -lt $((${#units[@]} - 1)) ]; do
        bytes=$((bytes / 1024))
        ((unit++))
    done
    
    echo "${bytes}${units[$unit]}"
}

### Human readable to bytes ###
human_to_bytes() {
    local input="$1"
    local number=$(echo "$input" | sed 's/[^0-9.]//g')
    local unit=$(echo "$input" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')
    
    case "$unit" in
        ""|"B")     echo "$number" ;;
        "K"|"KB")   echo $((${number%.*} * 1024)) ;;
        "M"|"MB")   echo $((${number%.*} * 1024 * 1024)) ;;
        "G"|"GB")   echo $((${number%.*} * 1024 * 1024 * 1024)) ;;
        "T"|"TB")   echo $((${number%.*} * 1024 * 1024 * 1024 * 1024)) ;;
        *)          echo "0" ;;
    esac
}

### Format duration ###
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

### Get timestamp ###
get_timestamp() {
    local format="${1:-%Y%m%d_%H%M%S}"
    date +"$format"
}

### Generate random string ###
generate_random() {
    local length="${1:-8}"
    local chars="${2:-A-Za-z0-9}"
    
    tr -dc "$chars" < /dev/urandom | head -c "$length"
}

### URL encode ###
url_encode() {
    local string="$1"
    local encoded=""
    local char
    
    for ((i=0; i<${#string}; i++)); do
        char="${string:$i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) encoded+="$char" ;;
            *) encoded+=$(printf '%%%02X' "'$char") ;;
        esac
    done
    
    echo "$encoded"
}

################################################################################
### CONFIGURATION FUNCTIONS
################################################################################

### Load configuration file ###
load_config() {
    local config_file="$1"
    local required="${2:-true}"
    
    if [ -f "$config_file" ]; then
        source "$config_file"
        log_info "Loaded configuration: $config_file"
        return 0
    elif [ "$required" = "true" ]; then
        error_exit "Required configuration file not found: $config_file"
    else
        log_warning "Optional configuration file not found: $config_file"
        return 1
    fi
}

### Save configuration ###
save_config() {
    local config_file="$1"
    shift
    local variables=("$@")
    
    {
        echo "### Auto-generated configuration ###"
        echo "### Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        for var in "${variables[@]}"; do
            if [ -n "${!var}" ]; then
                echo "$var=\"${!var}\""
            fi
        done
    } > "$config_file"
    
    log_info "Configuration saved: $config_file"
}

### Get config value with default ###
get_config() {
    local var_name="$1"
    local default_value="$2"
    local current_value="${!var_name}"
    
    echo "${current_value:-$default_value}"
}

################################################################################
### NETWORK FUNCTIONS
################################################################################

### Check internet connectivity ###
check_internet() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    return 1
}

### Download file with retry ###
download_file() {
    local url="$1"
    local output="$2"
    local max_attempts="${3:-3}"
    
    log_info "Downloading: $url"
    
    if retry_command "$max_attempts" 5 "wget -O '$output' '$url'"; then
        log_info "Download completed: $output"
        return 0
    else
        log_error "Download failed: $url"
        return 1
    fi
}

### Check URL availability ###
check_url() {
    local url="$1"
    local timeout="${2:-10}"
    
    if command -v curl >/dev/null 2>&1; then
        curl -s --head --connect-timeout "$timeout" "$url" >/dev/null 2>&1
    elif command -v wget >/dev/null 2>&1; then
        wget --spider --timeout="$timeout" "$url" >/dev/null 2>&1
    else
        return 1
    fi
}

################################################################################
### CLEANUP FUNCTIONS
################################################################################

### Setup cleanup trap ###
setup_cleanup() {
    trap 'cleanup_on_exit $?' EXIT
    trap 'cleanup_on_signal SIGINT' INT
    trap 'cleanup_on_signal SIGTERM' TERM
}

### Cleanup on exit ###
cleanup_on_exit() {
    local exit_code=$1
    
    if [ "$exit_code" -ne 0 ]; then
        log_error "Script exited with error code: $exit_code"
    fi
    
    ### Call custom cleanup if defined ###
    if declare -f cleanup >/dev/null 2>&1; then
        cleanup
    fi
}

### Cleanup on signal ###
cleanup_on_signal() {
    local signal=$1
    log_warning "Received signal: $signal"
    
    ### Call custom cleanup if defined ###
    if declare -f cleanup >/dev/null 2>&1; then
        cleanup
    fi
    
    exit 130
}

### Unmount filesystems safely ###
safe_unmount() {
    local mount_point="$1"
    local max_attempts="${2:-3}"
    
    if ! mount | grep -q "$mount_point"; then
        return 0
    fi
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if umount "$mount_point" 2>/dev/null; then
            log_info "Unmounted: $mount_point"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warning "Unmount failed (attempt $attempt), retrying..."
            sleep 2
            
            ### Try to kill processes using the mount point ###
            if command -v fuser >/dev/null 2>&1; then
                fuser -k "$mount_point" 2>/dev/null || true
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Failed to unmount: $mount_point"
    return 1
}

### Remove loop devices ###
cleanup_loop_devices() {
    local pattern="${1:-/dev/loop}"
    
    for loop in $(losetup -a | grep "$pattern" | cut -d: -f1); do
        if losetup -d "$loop" 2>/dev/null; then
            log_info "Detached loop device: $loop"
        fi
    done
}

################################################################################
### INTERACTION FUNCTIONS
################################################################################

### Ask yes/no question ###
ask_yes_no() {
    local question="$1"
    local default="${2:-no}"
    
    local prompt="$question"
    case "$default" in
        yes|y) prompt="$prompt [Y/n]" ;;
        no|n)  prompt="$prompt [y/N]" ;;
        *)     prompt="$prompt [y/n]" ;;
    esac
    
    while true; do
        read -p "$prompt: " answer
        
        ### Use default if empty ###
        if [ -z "$answer" ]; then
            answer="$default"
        fi
        
        case "$answer" in
            yes|y|Y|YES) return 0 ;;
            no|n|N|NO)   return 1 ;;
            *) print_warning "Please answer yes or no" ;;
        esac
    done
}

### Ask for input with validation ###
ask_input() {
    local prompt="$1"
    local default="$2"
    local validator="$3"  ### Optional validation function ###
    
    while true; do
        if [ -n "$default" ]; then
            read -p "$prompt [$default]: " input
            input="${input:-$default}"
        else
            read -p "$prompt: " input
        fi
        
        ### Validate input if validator provided ###
        if [ -n "$validator" ] && declare -f "$validator" >/dev/null 2>&1; then
            if "$validator" "$input"; then
                echo "$input"
                return 0
            else
                print_warning "Invalid input, please try again"
            fi
        else
            echo "$input"
            return 0
        fi
    done
}

### Select from menu ###
select_from_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    print_subheader "$title"
    
    for i in "${!options[@]}"; do
        print_msg "$WHITE" "  [$((i+1))] ${options[$i]}"
    done
    print_msg "$WHITE" "  [0] Cancel"
    echo ""
    
    while true; do
        read -p "Please select [0-${#options[@]}]: " selection
        
        if [ "$selection" = "0" ]; then
            return 1
        elif [ "$selection" -ge 1 ] && [ "$selection" -le "${#options[@]}" ] 2>/dev/null; then
            echo $((selection - 1))
            return 0
        else
            print_warning "Invalid selection"
        fi
    done
}

################################################################################
### INITIALIZATION
################################################################################

### Initialize helper functions ###
init_helpers() {
    local script_name="${1:-${0##*/}}"
    local log_file="$2"
    local quiet_mode="${3:-false}"
    local verbose_mode="${4:-false}"
    
    ### Set global modes ###
    export DEFAULT_QUIET_MODE="$quiet_mode"
    export DEFAULT_VERBOSE_MODE="$verbose_mode"
    
    ### Initialize logging if log file provided ###
    if [ -n "$log_file" ]; then
        init_logging "$log_file"
    fi
    
    ### Setup cleanup ###
    setup_cleanup
    
    log_info "Helper functions initialized for: $script_name"
}

################################################################################
### EXPORT FUNCTIONS
################################################################################

### Export all helper functions ###
export -f print_msg print_plain print_timestamped
export -f print_header print_subheader print_section print_step print_box
export -f print_success print_error print_warning print_info print_bullet print_check print_cross print_progress
export -f init_logging log_message log_debug log_info log_warning log_error log_print
export -f error_exit check_command retry_command
export -f check_root check_command_exists check_required_commands check_disk_space validate_directory validate_file
export -f bytes_to_human human_to_bytes format_duration get_timestamp generate_random url_encode
export -f load_config save_config get_config
export -f check_internet download_file check_url
export -f setup_cleanup cleanup_on_exit cleanup_on_signal safe_unmount cleanup_loop_devices
export -f ask_yes_no ask_input select_from_menu
export -f init_helpers

################################################################################
### END OF HELPER FUNCTIONS
################################################################################