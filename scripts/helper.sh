#!/bin/bash
################################################################################
### Universal Helper Functions - Complete Utility Library
### Comprehensive Collection of Helper Functions for bash Scripts
### Provides Output, Logging, Validation, System, Network and Utility Functions
################################################################################
### Project: Universal Helper Library
### Version: 2.0.0
### Author:  Mawage (Development Team)
### Date:    2025-01-01
### License: MIT
### Usage:   Source this File to load Helper Functions
################################################################################

SCRIPT_VERSION="2.0.0"
COMMIT="Complete helper functions library for bash scripts"

### Prevent multiple inclusion ###
if [ -n "$HELPER_FUNCTIONS_LOADED" ]; then
    return 0
fi
HELPER_FUNCTIONS_LOADED=1

################################################################################
### === INITIALIZATION === ###
################################################################################

### Load Project Configuration and Helper Functions ###
load_config() {
    ### Determine project root dynamically ###
    local script_path="$(realpath "${BASH_SOURCE[0]}")"
    local script_dir="$(dirname "$script_path")"
    local project_root="$(dirname "$script_dir")"
    
    ### Look for project.conf in standard locations ###
    local config_file=""
    if [ -f "$project_root/configs/project.conf" ]; then
        config_file="$project_root/configs/project.conf"
    elif [ -f "$project_root/project.conf" ]; then
        config_file="$project_root/project.conf"
    else
        echo "ERROR: Project configuration not found in $project_root"
        exit 1
    fi
    
    ### Load project configuration ###
    source "$config_file"
    
}


################################################################################
### === GLOBAL VARIABLES AND CONSTANTS === ###
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
export DEFAULT_LOG_FILE="/tmp/script.log"
export DEFAULT_QUIET_MODE=false
export DEFAULT_VERBOSE_MODE=false

################################################################################
### === OUTPUT & FORMATTING FUNCTIONS === ###
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
        print_msg "$CYAN" "-------------------------------------------------------------------------------"
        print_msg "$CYAN" "  $1"
        print_msg "$CYAN" "-------------------------------------------------------------------------------"
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
### === STATUS & NOTIFICATION FUNCTIONS === ###
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

### Show progress bar ###
show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    
    ### Calculate percentage ###
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    ### Build progress bar ###
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' '-'
    printf "] %3d%% (%d/%d)" "$percent" "$current" "$total"
}

### Show spinner ###
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

################################################################################
### === LOGGING FUNCTIONS === ###
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
        echo "### Log Started: $(date '+%Y-%m-%d %H:%M:%S')"
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
### === ERROR HANDLING FUNCTIONS === ###
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
### === SYSTEM CHECK FUNCTIONS === ###
################################################################################

### Check if running as root (with exit) ###
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (sudo)"
    fi
}

### Simple root check (boolean) ###
is_root() {
    [[ $EUID -eq 0 ]]
}

### Check if command exists (with exit) ###
check_command_exists() {
    local command="$1"
    local package_hint="$2"
    
    if ! command -v "$command" >/dev/null 2>&1; then
        local message="Required command not found: $command"
        [ -n "$package_hint" ] && message="$message (try: apt install $package_hint)"
        error_exit "$message"
    fi
}

### Simple command check (boolean) ###
command_exists() {
    command -v "$1" >/dev/null 2>&1
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

### Detect operating system ###
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
        echo "windows"
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        echo "freebsd"
    else
        echo "unknown"
    fi
}

### Detect Linux distribution ###
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID,,}"  ### Convert to lowercase ###
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "redhat"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

### Detect package manager ###
detect_package_manager() {
    if command_exists apt; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists brew; then
        echo "brew"
    elif command_exists apk; then
        echo "apk"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

### Get system information ###
get_system_info() {
    echo "OS: $(detect_os)"
    echo "Distro: $(detect_distro)"
    echo "Package Manager: $(detect_package_manager)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
    echo "Memory: $(free -h | awk 'NR==2 {print $2}')"
    echo "Disk: $(df -h / | awk 'NR==2 {print $2}')"
}

################################################################################
### === VALIDATION FUNCTIONS === ###
################################################################################

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

### Validate path ###
validate_path() {
    local path="$1"
    
    if [ -e "$path" ]; then
        if [ -f "$path" ]; then
            echo "file"
        elif [ -d "$path" ]; then
            echo "directory"
        elif [ -L "$path" ]; then
            echo "symlink"
        else
            echo "other"
        fi
        return 0
    else
        return 1
    fi
}

### Validate permissions ###
validate_permissions() {
    local path="$1"
    local required_perms="$2"  ### e.g. "rwx" or "r" ###
    
    local can_read=false
    local can_write=false
    local can_execute=false
    
    [ -r "$path" ] && can_read=true
    [ -w "$path" ] && can_write=true
    [ -x "$path" ] && can_execute=true
    
    for perm in $(echo "$required_perms" | grep -o .); do
        case "$perm" in
            r) [ "$can_read" = "false" ] && return 1 ;;
            w) [ "$can_write" = "false" ] && return 1 ;;
            x) [ "$can_execute" = "false" ] && return 1 ;;
        esac
    done
    
    return 0
}

### Validate email ###
validate_email() {
    local email="$1"
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ $email =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

### Validate URL ###
validate_url() {
    local url="$1"
    local regex="^(https?|ftp)://[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})(:[0-9]+)?(/.*)?$"
    
    if [[ $url =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

### Validate IP address ###
validate_ip() {
    local ip="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ $ip =~ $regex ]]; then
        ### Check each octet ###
        IFS='.' read -ra OCTETS <<< "$ip"
        for octet in "${OCTETS[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

### Validate port number ###
validate_port() {
    local port="$1"
    
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

################################################################################
### === FILE OPERATION FUNCTIONS === ###
################################################################################

### Create timestamped backup ###
backup_file() {
    local file="$1"
    local backup_dir="${2:-}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -n "$backup_dir" ]; then
        mkdir -p "$backup_dir"
        cp "$file" "$backup_dir/$(basename "$file").bak.$timestamp"
    else
        cp "$file" "${file}.bak.$timestamp"
    fi
}

### Safe copy with verification ###
safe_copy() {
    local source="$1"
    local dest="$2"
    local backup="${3:-false}"
    
    ### Backup destination if it exists ###
    if [ -f "$dest" ] && [ "$backup" = "true" ]; then
        backup_file "$dest"
    fi
    
    ### Copy file ###
    if cp "$source" "$dest"; then
        ### Verify copy ###
        if cmp -s "$source" "$dest"; then
            log_info "Successfully copied: $source -> $dest"
            return 0
        else
            log_error "Copy verification failed: $source -> $dest"
            return 1
        fi
    else
        log_error "Copy failed: $source -> $dest"
        return 1
    fi
}

### Safe move ###
safe_move() {
    local source="$1"
    local dest="$2"
    local backup="${3:-false}"
    
    ### Backup destination if it exists ###
    if [ -f "$dest" ] && [ "$backup" = "true" ]; then
        backup_file "$dest"
    fi
    
    ### Move file ###
    if mv "$source" "$dest"; then
        log_info "Successfully moved: $source -> $dest"
        return 0
    else
        log_error "Move failed: $source -> $dest"
        return 1
    fi
}

### Safe delete with confirmation ###
safe_delete() {
    local target="$1"
    local force="${2:-false}"
    
    if [ ! -e "$target" ]; then
        log_warning "Target does not exist: $target"
        return 1
    fi
    
    if [ "$force" != "true" ]; then
        if ! ask_yes_no "Are you sure you want to delete $target?"; then
            log_info "Deletion cancelled: $target"
            return 1
        fi
    fi
    
    rm -rf "$target" && log_info "Deleted: $target"
}

### Create temporary file ###
create_temp_file() {
    local prefix="${1:-temp}"
    local suffix="${2:-.tmp}"
    
    mktemp "/tmp/${prefix}.XXXXXX${suffix}"
}

### Create temporary directory ###
create_temp_dir() {
    local prefix="${1:-tempdir}"
    
    mktemp -d "/tmp/${prefix}.XXXXXX"
}

### Find files with pattern ###
find_files() {
    local search_path="$1"
    local pattern="$2"
    local type="${3:-f}"  ### f=file, d=directory ###
    
    find "$search_path" -type "$type" -name "$pattern" 2>/dev/null
}

################################################################################
### === PACKAGE MANAGEMENT FUNCTIONS === ###
################################################################################

### Install package with auto-detection ###
install_package() {
    local package="$1"
    local pm=$(detect_package_manager)
    
    log_info "Installing package: $package (using $pm)"
    
    case "$pm" in
        apt)
            sudo apt update && sudo apt install -y "$package"
            ;;
        yum)
            sudo yum install -y "$package"
            ;;
        dnf)
            sudo dnf install -y "$package"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$package"
            ;;
        brew)
            brew install "$package"
            ;;
        apk)
            sudo apk add "$package"
            ;;
        zypper)
            sudo zypper install -y "$package"
            ;;
        *)
            log_error "Unknown package manager"
            return 1
            ;;
    esac
}

### Remove package ###
remove_package() {
    local package="$1"
    local pm=$(detect_package_manager)
    
    log_info "Removing package: $package (using $pm)"
    
    case "$pm" in
        apt)
            sudo apt remove -y "$package"
            ;;
        yum)
            sudo yum remove -y "$package"
            ;;
        dnf)
            sudo dnf remove -y "$package"
            ;;
        pacman)
            sudo pacman -R --noconfirm "$package"
            ;;
        brew)
            brew uninstall "$package"
            ;;
        apk)
            sudo apk del "$package"
            ;;
        zypper)
            sudo zypper remove -y "$package"
            ;;
        *)
            log_error "Unknown package manager"
            return 1
            ;;
    esac
}

### Update package list ###
update_package_list() {
    local pm=$(detect_package_manager)
    
    log_info "Updating package list (using $pm)"
    
    case "$pm" in
        apt)
            sudo apt update
            ;;
        yum)
            sudo yum check-update || true
            ;;
        dnf)
            sudo dnf check-update || true
            ;;
        pacman)
            sudo pacman -Sy
            ;;
        brew)
            brew update
            ;;
        apk)
            sudo apk update
            ;;
        zypper)
            sudo zypper refresh
            ;;
        *)
            log_error "Unknown package manager"
            return 1
            ;;
    esac
}

### Check if package is installed ###
is_package_installed() {
    local package="$1"
    local pm=$(detect_package_manager)
    
    case "$pm" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        yum|dnf)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Q "$package" >/dev/null 2>&1
            ;;
        brew)
            brew list "$package" >/dev/null 2>&1
            ;;
        apk)
            apk info -e "$package" >/dev/null 2>&1
            ;;
        zypper)
            zypper se -i "$package" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

################################################################################
### === UTILITY - CONVERSION FUNCTIONS === ###
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
### === UTILITY - TEXT FUNCTIONS === ###
################################################################################

### Trim whitespace ###
trim() {
    local string="$1"
    echo "$string" | xargs
}

### Convert to lowercase ###
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

### Convert to uppercase ###
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

### Pad string ###
pad_string() {
    local string="$1"
    local length="$2"
    local char="${3:- }"
    local align="${4:-left}"  ### left, right, center ###
    
    local current_length=${#string}
    
    if [ $current_length -ge $length ]; then
        echo "$string"
        return
    fi
    
    local padding=$((length - current_length))
    
    case "$align" in
        left)
            printf "%s%*s" "$string" "$padding" "" | tr ' ' "$char"
            ;;
        right)
            printf "%*s%s" "$padding" "" "$string" | tr ' ' "$char"
            ;;
        center)
            local left_pad=$((padding / 2))
            local right_pad=$((padding - left_pad))
            printf "%*s%s%*s" "$left_pad" "" "$string" "$right_pad" "" | tr ' ' "$char"
            ;;
    esac
}

### Truncate string ###
truncate_string() {
    local string="$1"
    local max_length="$2"
    local suffix="${3:-...}"
    
    if [ ${#string} -le $max_length ]; then
        echo "$string"
    else
        local truncate_at=$((max_length - ${#suffix}))
        echo "${string:0:$truncate_at}$suffix"
    fi
}

### Escape regex special characters ###
escape_regex() {
    local string="$1"
    echo "$string" | sed 's/[][\.|$*+?{}()^]/\\&/g'
}

################################################################################
### === CONFIGURATION FUNCTIONS === ###
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

### Merge configurations ###
merge_config() {
    local base_config="$1"
    local override_config="$2"
    local output_config="$3"
    
    ### Load base configuration ###
    if [ -f "$base_config" ]; then
        cp "$base_config" "$output_config"
    fi
    
    ### Apply overrides ###
    if [ -f "$override_config" ]; then
        while IFS='=' read -r key value; do
            ### Skip comments and empty lines ###
            [[ "$key" =~ ^#.*$ ]] && continue
            [ -z "$key" ] && continue
            
            ### Remove existing key and add new value ###
            sed -i "/^$key=/d" "$output_config"
            echo "$key=$value" >> "$output_config"
        done < "$override_config"
    fi
    
    log_info "Merged configuration: $base_config + $override_config -> $output_config"
}

### Validate configuration ###
validate_config() {
    local config_file="$1"
    shift
    local required_vars=("$@")
    
    ### Source config file ###
    source "$config_file"
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required configuration variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

### Export configuration as environment variables ###
export_config() {
    local config_file="$1"
    local prefix="${2:-}"
    
    if [ ! -f "$config_file" ]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    while IFS='=' read -r key value; do
        ### Skip comments and empty lines ###
        [[ "$key" =~ ^#.*$ ]] && continue
        [ -z "$key" ] && continue
        
        ### Remove quotes from value ###
        value="${value%\"}"
        value="${value#\"}"
        
        ### Export with optional prefix ###
        if [ -n "$prefix" ]; then
            export "${prefix}_${key}=$value"
        else
            export "$key=$value"
        fi
    done < "$config_file"
}

################################################################################
### === NETWORK FUNCTIONS === ###
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

### Download with progress ###
download_with_progress() {
    local url="$1"
    local output="$2"
    
    if command_exists curl; then
        print_info "Downloading using curl..."
        curl -# -L "$url" -o "$output"
    elif command_exists wget; then
        print_info "Downloading using wget..."
        wget --progress=bar:force:noscroll "$url" -O "$output"
    else
        log_error "Neither curl nor wget available"
        return 1
    fi
}

### Upload file ###
upload_file() {
    local file="$1"
    local url="$2"
    local method="${3:-POST}"
    
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi
    
    if command_exists curl; then
        curl -X "$method" -F "file=@$file" "$url"
    else
        log_error "curl not available for upload"
        return 1
    fi
}

### Get public IP ###
get_public_ip() {
    local services=(
        "https://api.ipify.org"
        "https://icanhazip.com"
        "https://ifconfig.me"
    )
    
    for service in "${services[@]}"; do
        local ip=$(curl -s --connect-timeout 3 "$service" 2>/dev/null)
        if validate_ip "$ip"; then
            echo "$ip"
            return 0
        fi
    done
    
    return 1
}

### Get local IP ###
get_local_ip() {
    local interface="${1:-}"
    
    if [ -n "$interface" ]; then
        ip addr show "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
    else
        hostname -I | awk '{print $1}'
    fi
}

### Test port connectivity ###
test_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-3}"
    
    if command_exists nc; then
        nc -z -w "$timeout" "$host" "$port" 2>/dev/null
    elif command_exists telnet; then
        timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
    else
        return 1
    fi
}

################################################################################
### === CLEANUP FUNCTIONS === ###
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
### === USER INTERACTION FUNCTIONS === ###
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

### Ask for password ###
ask_password() {
    local prompt="${1:-Enter password}"
    local verify="${2:-false}"
    
    while true; do
        read -s -p "$prompt: " password
        echo ""
        
        if [ "$verify" = "true" ]; then
            read -s -p "Verify password: " password2
            echo ""
            
            if [ "$password" = "$password2" ]; then
                echo "$password"
                return 0
            else
                print_error "Passwords do not match. Please try again."
            fi
        else
            echo "$password"
            return 0
        fi
    done
}

### Confirm action ###
confirm_action() {
    local action="$1"
    local danger="${2:-false}"
    
    if [ "$danger" = "true" ]; then
        print_warning "⚠️  This action cannot be undone!"
    fi
    
    ask_yes_no "Are you sure you want to $action?" "no"
}

### Pause execution ###
pause() {
    local message="${1:-Press Enter to continue...}"
    read -p "$message" -r
}

### Countdown timer ###
countdown() {
    local seconds="${1:-10}"
    local message="${2:-Continuing in}"
    
    while [ $seconds -gt 0 ]; do
        printf "\r%s %d seconds... " "$message" "$seconds"
        sleep 1
        ((seconds--))
    done
    printf "\r%*s\r" ${#message} ""  ### Clear line ###
}

### Show generic menu template ###
show_menu() {
    local title="$1"
    local ps3="${2:-Please select an option: }"
    shift 2
    local options=("$@")
    
    print_header "$title"
    
    PS3="$ps3"
    select opt in "${options[@]}" "Quit"; do
        if [ "$opt" = "Quit" ]; then
            echo "quit"
            return 0
        elif [ -n "$opt" ]; then
            echo "$REPLY"
            return 0
        else
            print_warning "Invalid option. Please try again."
        fi
    done
}

################################################################################
### === PROCESS MANAGEMENT FUNCTIONS === ###
################################################################################

### Run command in background ###
run_in_background() {
    local command="$1"
    local log_file="${2:-/dev/null}"
    
    nohup bash -c "$command" > "$log_file" 2>&1 &
    local pid=$!
    
    log_info "Started background process: PID=$pid, Command=$command"
    echo "$pid"
}

### Wait for process ###
wait_for_process() {
    local pid="$1"
    local timeout="${2:-0}"  ### 0 = no timeout ###
    
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ "$timeout" -gt 0 ] && [ "$elapsed" -ge "$timeout" ]; then
            log_warning "Process $pid timed out after ${timeout}s"
            return 1
        fi
        sleep 1
        ((elapsed++))
    done
    
    log_info "Process $pid completed after ${elapsed}s"
    return 0
}

### Kill process tree ###
kill_process_tree() {
    local pid="$1"
    local signal="${2:-TERM}"
    
    ### Get all child processes ###
    local children=$(pgrep -P "$pid" 2>/dev/null)
    
    ### Kill children first ###
    for child in $children; do
        kill_process_tree "$child" "$signal"
    done
    
    ### Kill parent ###
    if kill -0 "$pid" 2>/dev/null; then
        kill -"$signal" "$pid"
        log_info "Killed process: $pid"
    fi
}

### Monitor process ###
monitor_process() {
    local pid="$1"
    local interval="${2:-5}"
    local callback="${3:-}"  ### Optional callback function ###
    
    while kill -0 "$pid" 2>/dev/null; do
        if [ -n "$callback" ] && declare -f "$callback" >/dev/null 2>&1; then
            "$callback" "$pid"
        fi
        sleep "$interval"
    done
}

### Create PID file ###
create_pidfile() {
    local pidfile="$1"
    local pid="${2:-$$}"
    
    ### Check if PID file already exists ###
    if [ -f "$pidfile" ]; then
        local old_pid=$(cat "$pidfile")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_error "Process already running with PID: $old_pid"
            return 1
        else
            log_warning "Removing stale PID file: $pidfile"
            rm -f "$pidfile"
        fi
    fi
    
    echo "$pid" > "$pidfile"
    log_info "Created PID file: $pidfile (PID=$pid)"
    return 0
}

### Check PID file ###
check_pidfile() {
    local pidfile="$1"
    
    if [ ! -f "$pidfile" ]; then
        return 1
    fi
    
    local pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
        echo "$pid"
        return 0
    else
        ### PID file exists but process is not running ###
        rm -f "$pidfile"
        return 1
    fi
}

################################################################################
### === INITIALIZATION FUNCTIONS === ###
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
### === EXPORT ALL FUNCTIONS === ###
################################################################################

### Export all helper functions for use in subshells ###
while IFS= read -r func; do
    export -f "$func"
done < <(declare -F | awk '{print $3}')

################################################################################
### === END OF HELPER FUNCTIONS === ###
################################################################################

### Print initialization message if verbose ###
if [ "$DEFAULT_VERBOSE_MODE" = "true" ]; then
    print_success "Helper functions v${SCRIPT_VERSION} loaded successfully"
fi


#!/bin/bash
################################################################################
### Modified Functions for helper.sh
################################################################################

################################################################################
### === MENU AND HELP === ###
################################################################################

### Show main interactive menu ###
show_menu() {
    clear
    print_header "Universal Helper Functions - Interactive Menu"
    
    echo "📋 AVAILABLE ACTIONS:"
    echo ""
    echo "  1) System Information"
    echo "  2) Test Network Connectivity"
    echo "  3) Check Required Commands"
    echo "  4) Package Management"
    echo "  5) File Operations"
    echo "  6) Configuration Tools"
    echo "  7) Process Management"
    echo "  8) Logging Functions"
    echo "  9) Show Function List"
    echo " 10) Run Custom Command"
    echo " 11) Show Help Documentation"
    echo " 12) Exit"
    echo ""
    
    read -p "Enter your choice [1-12]: " choice
    
    case $choice in
        1)
            show_system_info_menu
            ;;
        2)
            show_network_menu
            ;;
        3)
            show_command_check_menu
            ;;
        4)
            show_package_menu
            ;;
        5)
            show_file_operations_menu
            ;;
        6)
            show_config_menu
            ;;
        7)
            show_process_menu
            ;;
        8)
            show_logging_menu
            ;;
        9)
            show_function_list
            ;;
        10)
            run_custom_command
            ;;
        11)
            show_help_documentation
            ;;
        12)
            print_info "Exiting Helper Functions Menu..."
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please select 1-12."
            pause "Press Enter to continue..."
            show_menu
            ;;
    esac
}

### Show system information submenu ###
show_system_info_menu() {
    clear
    print_header "System Information"
    
    echo "Select information to display:"
    echo ""
    echo "  1) Complete System Info"
    echo "  2) Operating System"
    echo "  3) Distribution"
    echo "  4) Package Manager"
    echo "  5) Hardware Info"
    echo "  6) Network Interfaces"
    echo "  7) Disk Usage"
    echo "  8) Memory Usage"
    echo "  9) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-9]: " choice
    
    case $choice in
        1)
            echo ""
            get_system_info
            ;;
        2)
            echo ""
            print_info "Operating System: $(detect_os)"
            ;;
        3)
            echo ""
            print_info "Distribution: $(detect_distro)"
            ;;
        4)
            echo ""
            print_info "Package Manager: $(detect_package_manager)"
            ;;
        5)
            echo ""
            print_info "Architecture: $(uname -m)"
            print_info "Kernel: $(uname -r)"
            print_info "Hostname: $(hostname)"
            ;;
        6)
            echo ""
            print_info "Local IP: $(get_local_ip)"
            if check_internet; then
                print_info "Public IP: $(get_public_ip || echo "Unable to determine")"
            else
                print_warning "No internet connection"
            fi
            ;;
        7)
            echo ""
            df -h
            ;;
        8)
            echo ""
            free -h
            ;;
        9)
            show_menu
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause "Press Enter to continue..."
    show_system_info_menu
}

### Show network connectivity menu ###
show_network_menu() {
    clear
    print_header "Network Connectivity Tests"
    
    echo "Select network test:"
    echo ""
    echo "  1) Check Internet Connection"
    echo "  2) Test URL Availability"
    echo "  3) Test Port Connectivity"
    echo "  4) Get Public IP"
    echo "  5) Get Local IP"
    echo "  6) Download Test File"
    echo "  7) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-7]: " choice
    
    case $choice in
        1)
            echo ""
            print_info "Testing internet connectivity..."
            if check_internet; then
                print_success "Internet connection is available"
            else
                print_error "No internet connection"
            fi
            ;;
        2)
            echo ""
            read -p "Enter URL to test: " test_url
            if [ -n "$test_url" ]; then
                print_info "Testing URL: $test_url"
                if check_url "$test_url"; then
                    print_success "URL is reachable"
                else
                    print_error "URL is not reachable"
                fi
            fi
            ;;
        3)
            echo ""
            read -p "Enter hostname/IP: " test_host
            read -p "Enter port number: " test_port
            if [ -n "$test_host" ] && [ -n "$test_port" ]; then
                print_info "Testing connection to $test_host:$test_port"
                if test_port "$test_host" "$test_port"; then
                    print_success "Port is open"
                else
                    print_error "Port is closed or unreachable"
                fi
            fi
            ;;
        4)
            echo ""
            print_info "Getting public IP address..."
            local public_ip=$(get_public_ip)
            if [ -n "$public_ip" ]; then
                print_success "Public IP: $public_ip"
            else
                print_error "Unable to determine public IP"
            fi
            ;;
        5)
            echo ""
            print_info "Local IP: $(get_local_ip)"
            ;;
        6)
            echo ""
            read -p "Enter URL to download: " download_url
            read -p "Enter output file name: " output_file
            if [ -n "$download_url" ] && [ -n "$output_file" ]; then
                download_file "$download_url" "$output_file"
            fi
            ;;
        7)
            show_menu
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause "Press Enter to continue..."
    show_network_menu
}

### Show command check menu ###
show_command_check_menu() {
    clear
    print_header "Command Availability Check"
    
    echo "Select check type:"
    echo ""
    echo "  1) Check Single Command"
    echo "  2) Check Multiple Commands"
    echo "  3) Check Common System Tools"
    echo "  4) Check Development Tools"
    echo "  5) Check Network Tools"
    echo "  6) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-6]: " choice
    
    case $choice in
        1)
            echo ""
            read -p "Enter command name: " cmd_name
            if [ -n "$cmd_name" ]; then
                if command_exists "$cmd_name"; then
                    print_success "Command '$cmd_name' is available"
                    print_info "Location: $(which "$cmd_name")"
                else
                    print_error "Command '$cmd_name' is not available"
                fi
            fi
            ;;
        2)
            echo ""
            read -p "Enter commands separated by spaces: " cmd_list
            if [ -n "$cmd_list" ]; then
                IFS=' ' read -ra COMMANDS <<< "$cmd_list"
                check_required_commands "${COMMANDS[@]}"
            fi
            ;;
        3)
            echo ""
            local system_tools=("ls" "cp" "mv" "rm" "mkdir" "chmod" "chown" "tar" "gzip" "wget" "curl")
            print_info "Checking common system tools..."
            for tool in "${system_tools[@]}"; do
                if command_exists "$tool"; then
                    print_check "$tool"
                else
                    print_cross "$tool"
                fi
            done
            ;;
        4)
            echo ""
            local dev_tools=("git" "gcc" "make" "python3" "node" "npm" "docker" "vim" "nano")
            print_info "Checking development tools..."
            for tool in "${dev_tools[@]}"; do
                if command_exists "$tool"; then
                    print_check "$tool"
                else
                    print_cross "$tool"
                fi
            done
            ;;
        5)
            echo ""
            local net_tools=("ping" "nc" "telnet" "ssh" "scp" "rsync" "nmap")
            print_info "Checking network tools..."
            for tool in "${net_tools[@]}"; do
                if command_exists "$tool"; then
                    print_check "$tool"
                else
                    print_cross "$tool"
                fi
            done
            ;;
        6)
            show_menu
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause "Press Enter to continue..."
    show_command_check_menu
}

### Show package management menu ###
show_package_menu() {
    clear
    print_header "Package Management"
    
    local pm=$(detect_package_manager)
    print_info "Detected package manager: $pm"
    echo ""
    
    echo "Select package operation:"
    echo ""
    echo "  1) Update package list"
    echo "  2) Install package"
    echo "  3) Remove package"
    echo "  4) Check if package is installed"
    echo "  5) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-5]: " choice
    
    case $choice in
        1)
            echo ""
            print_info "Updating package list..."
            update_package_list
            print_success "Package list updated"
            ;;
        2)
            echo ""
            read -p "Enter package name to install: " pkg_name
            if [ -n "$pkg_name" ]; then
                install_package "$pkg_name"
            fi
            ;;
        3)
            echo ""
            read -p "Enter package name to remove: " pkg_name
            if [ -n "$pkg_name" ] && confirm_action "remove package '$pkg_name'" true; then
                remove_package "$pkg_name"
            fi
            ;;
        4)
            echo ""
            read -p "Enter package name to check: " pkg_name
            if [ -n "$pkg_name" ]; then
                if is_package_installed "$pkg_name"; then
                    print_success "Package '$pkg_name' is installed"
                else
                    print_error "Package '$pkg_name' is not installed"
                fi
            fi
            ;;
        5)
            show_menu
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause "Press Enter to continue..."
    show_package_menu
}

### Show file operations menu ###
show_file_operations_menu() {
    clear
    print_header "File Operations"
    
    echo "Select file operation:"
    echo ""
    echo "  1) Validate Directory"
    echo "  2) Validate File"
    echo "  3) Create Backup"
    echo "  4) Safe Copy"
    echo "  5) Safe Move"
    echo "  6) Safe Delete"
    echo "  7) Find Files"
    echo "  8) Check Permissions"
    echo "  9) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-9]: " choice
    
    case $choice in
        1)
            echo ""
            read -p "Enter directory path: " dir_path
            if [ -n "$dir_path" ]; then
                validate_directory "$dir_path" true
                print_success "Directory validation completed"
            fi
            ;;
        2)
            echo ""
            read -p "Enter file path: " file_path
            if [ -n "$file_path" ]; then
                if validate_file "$file_path" false; then
                    print_success "File exists: $file_path"
                else
                    print_error "File not found: $file_path"
                fi
            fi
            ;;
        3)
            echo ""
            read -p "Enter file path to backup: " file_path
            if [ -n "$file_path" ] && [ -f "$file_path" ]; then
                backup_file "$file_path"
                print_success "Backup created for: $file_path"
            else
                print_error "File not found or invalid path"
            fi
            ;;
        4)
            echo ""
            read -p "Enter source file: " src_file
            read -p "Enter destination: " dest_file
            if [ -n "$src_file" ] && [ -n "$dest_file" ]; then
                safe_copy "$src_file" "$dest_file" true
            fi
            ;;
        5)
            echo ""
            read -p "Enter source file: " src_file
            read -p "Enter destination: " dest_file
            if [ -n "$src_file" ] && [ -n "$dest_file" ]; then
                safe_move "$src_file" "$dest_file" true
            fi
            ;;
        6)
            echo ""
            read -p "Enter file/directory to delete: " target_path
            if [ -n "$target_path" ]; then
                safe_delete "$target_path"
            fi
            ;;
        7)
            echo ""
            read -p "Enter search path: " search_path
            read -p "Enter file pattern: " pattern
            if [ -n "$search_path" ] && [ -n "$pattern" ]; then
                echo ""
                print_info "Found files:"
                find_files "$search_path" "$pattern"
            fi
            ;;
        8)
            echo ""
            read -p "Enter path to check: " check_path
            read -p "Enter required permissions (rwx): " perms
            if [ -n "$check_path" ] && [ -n "$perms" ]; then
                if validate_permissions "$check_path" "$perms"; then
                    print_success "Required permissions are available"
                else
                    print_error "Required permissions are missing"
                fi
            fi
            ;;
        9)
            show_menu
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause "Press Enter to continue..."
    show_file_operations_menu
}

### Show configuration menu ###
show_config_menu() {
    clear
    print_header "Configuration Tools"
    
    echo "Select configuration operation:"
    echo ""
    echo "  1) Load Configuration File"
    echo "  2) Validate Configuration"
    echo "  3) Export Configuration as Environment Variables"
    echo "  4) Show Current Environment Variables"
    echo "  5) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-5]: " choice
    
    case $choice in
        1)
            echo ""
            read -p "Enter configuration file path: " config_path
            if [ -n "$config_path" ]; then
                load_config "$config_path" false
            fi
            ;;
        2)
            echo ""
            read -p "Enter configuration file path: " config_path
            if [ -n "$config_path" ]; then
                read -p "Enter required variables (space-separated): " required_vars
                if [ -n "$required_vars" ]; then
                    IFS=' ' read -ra VARS <<< "$required_vars"
                    validate_config "$config_path" "${VARS[@]}"
                fi
            fi
            ;;
        3)
            echo ""
            read -p "Enter configuration file path: " config_path
            read -p "Enter variable prefix (optional): " prefix
            if [ -n "$config_path" ]; then
                export_config "$config_path" "$prefix"
                print_success "Configuration exported to environment"
            fi
            ;;
        4)
            echo ""
            print_info "Current environment variables:"
            env | sort
            ;;
        5)
            show_menu
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause "Press Enter to continue..."
    show_config_menu
}

### Show process management menu ###
show_process_menu() {
    clear
    print_header "Process Management"
    
    echo "Select process operation:"
    echo ""
    echo "  1) Run Command in Background"
    echo "  2) Monitor Running Processes"
    echo "  3) Create PID File"
    echo "  4) Check PID File"
    echo "  5) Kill Process Tree"
    echo "  6) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-6]: " choice
    
    case $choice in
        1)
            echo ""
            read -p "Enter command to run in background: " bg_command
            read -p "Enter log file path (optional): " log_file
            if [ -n "$bg_command" ]; then
                local pid=$(run_in_background "$bg_command" "${log_file:-/dev/null}")
                print_success "Started background process with PID: $pid"
            fi
            ;;
        2)
            echo ""
            print_info "Current processes:"
            ps aux | head -20
            ;;
        3)
            echo ""
            read -p "Enter PID file path: " pidfile_path
            if [ -n "$pidfile_path" ]; then
                create_pidfile "$pidfile_path"
            fi
            ;;
        4)
            echo ""
            read -p "Enter PID file path: " pidfile_path
            if [ -n "$pidfile_path" ]; then
                local pid=$(check_pidfile "$pidfile_path")
                if [ $? -eq 0 ]; then
                    print_success "Process is running with PID: $pid"
                else
                    print_error "Process is not running or PID file not found"
                fi
            fi
            ;;
        5)
            echo ""
            read -p "Enter PID to kill: " target_pid
            read -p "Enter signal (default: TERM): " signal
            if [ -n "$target_pid" ] && confirm_action "kill process tree for PID $target_pid" true; then
                kill_process_tree "$target_pid" "${signal:-TERM}"
            fi
            ;;
        6)
            show_menu
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause "Press Enter to continue..."
    show_process_menu
}

### Show logging menu ###
show_logging_menu() {
    clear
    print_header "Logging Functions"
    
    echo "Select logging operation:"
    echo ""
    echo "  1) Initialize Logging"
    echo "  2) Log Test Messages"
    echo "  3) Show Current Log File"
    echo "  4) View Log File"
    echo "  5) Clear Log File"
    echo "  6) Back to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-6]: " choice
    
    case $choice in
        1)
            echo ""
            read -p "Enter log file path [/tmp/helper.log]: " log_path
            log_path="${log_path:-/tmp/helper.log}"
            read -p "Enter log level (0-3) [1]: " log_level
            log_level="${log_level:-1}"
            init_logging "$log_path" "$log_level"
            print_success "Logging initialized: $log_path"
            ;;
        2)
            echo ""
            print_info "Generating test log messages..."
            log_debug "This is a debug message"
            log_info "This is an info message"
            log_warning "This is a warning message"
            log_error "This is an error message"
            print_success "Test messages logged"
            ;;
        3)
            echo ""
            print_info "Current log file: ${CURRENT_LOG_FILE:-Not initialized}"
            print_info "Current log level: ${CURRENT_LOG_LEVEL:-Not set}"
            ;;
        4)
            echo ""
            if [ -n "$CURRENT_LOG_FILE" ] && [ -f "$CURRENT_LOG_FILE" ]; then
                print_info "Showing last 20 lines of log file:"
                echo ""
                tail -20 "$CURRENT_LOG_FILE"
            else
                print_error "No log file available"
            fi
            ;;
        5)
            echo ""
            if [ -n "$CURRENT_LOG_FILE" ] && confirm_action "clear the log file" false; then
                > "$CURRENT_LOG_FILE"
                print_success "Log file cleared"
            fi
            ;;
        6)
            show_menu
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    pause "Press Enter to continue..."
    show_logging_menu
}

### Show available functions list ###
show_function_list() {
    clear
    print_header "Available Helper Functions"
    
    echo "📋 FUNCTION CATEGORIES:"
    echo ""
    
    print_subheader "Output & Formatting Functions"
    echo "  print_msg, print_header, print_success, print_error, print_warning, print_info"
    echo "  print_section, print_step, print_box, print_bullet, print_progress"
    echo ""
    
    print_subheader "System Check Functions"
    echo "  check_root, is_root, command_exists, check_required_commands"
    echo "  detect_os, detect_distro, detect_package_manager, get_system_info"
    echo ""
    
    print_subheader "Validation Functions"
    echo "  validate_directory, validate_file, validate_path, validate_permissions"
    echo "  validate_email, validate_url, validate_ip, validate_port"
    echo ""
    
    print_subheader "File Operation Functions"
    echo "  backup_file, safe_copy, safe_move, safe_delete, find_files"
    echo "  create_temp_file, create_temp_dir"
    echo ""
    
    print_subheader "Network Functions"
    echo "  check_internet, download_file, check_url, get_public_ip, get_local_ip"
    echo "  test_port, upload_file"
    echo ""
    
    print_subheader "Package Management Functions"
    echo "  install_package, remove_package, update_package_list, is_package_installed"
    echo ""
    
    print_subheader "Utility Functions"
    echo "  bytes_to_human, format_duration, get_timestamp, generate_random"
    echo "  trim, to_lower, to_upper, pad_string, truncate_string"
    echo ""
    
    print_subheader "Configuration Functions"
    echo "  load_config, save_config, get_config, validate_config, export_config"
    echo ""
    
    print_subheader "User Interaction Functions"
    echo "  ask_yes_no, ask_input, ask_password, confirm_action, pause, countdown"
    echo ""
    
    print_subheader "Process Management Functions"
    echo "  run_in_background, wait_for_process, kill_process_tree, monitor_process"
    echo "  create_pidfile, check_pidfile"
    echo ""
    
    print_subheader "Logging Functions"
    echo "  init_logging, log_debug, log_info, log_warning, log_error"
    echo ""
    
    pause "Press Enter to continue..."
    show_menu
}

### Run custom command with helper functions ###
run_custom_command() {
    clear
    print_header "Run Custom Command"
    
    print_info "You can use any helper function or system command."
    print_info "Type 'back' to return to main menu."
    echo ""
    
    while true; do
        read -p "Enter command: " custom_cmd
        
        case "$custom_cmd" in
            "back"|"exit"|"quit")
                show_menu
                return
                ;;
            "")
                continue
                ;;
            *)
                echo ""
                eval "$custom_cmd"
                echo ""
                ;;
        esac
    done
}

### Show help documentation ###
show_help_documentation() {
    clear
    print_header "Universal Helper Functions - Documentation"
    
    echo "🔧 DESCRIPTION:"
    echo "    Complete utility library for bash scripts providing output formatting,"
    echo "    system checks, file operations, network functions, and more."
    echo ""
    echo "📌 USAGE:"
    echo "    source helper.sh           # Load all functions into current shell"
    echo "    ./helper.sh                # Run interactive menu"
    echo "    ./helper.sh --help         # Show this documentation"
    echo ""
    echo "🎯 KEY FEATURES:"
    echo "    • Colored output and formatting functions"
    echo "    • Comprehensive logging with multiple levels"
    echo "    • System information and validation"
    echo "    • File operations with safety checks"
    echo "    • Network connectivity testing"
    echo "    • Package management abstraction"
    echo "    • Configuration file handling"
    echo "    • User interaction utilities"
    echo "    • Process management tools"
    echo "    • Error handling and cleanup"
    echo ""
    echo "📚 FUNCTION CATEGORIES:"
    echo "    1. Output & Formatting  - Colored messages, headers, progress bars"
    echo "    2. System Checks       - OS detection, command availability"
    echo "    3. Validation          - Files, directories, URLs, IPs"
    echo "    4. File Operations     - Safe copy/move, backups, permissions"
    echo "    5. Network Functions   - Connectivity tests, downloads"
    echo "    6. Package Management  - Install/remove with auto-detection"
    echo "    7. Configuration       - Load/save/validate config files"
    echo "    8. User Interaction    - Prompts, menus, confirmations"
    echo "    9. Process Management  - Background jobs, PID files"
    echo "   10. Logging            - Multi-level logging with timestamps"
    echo ""
    echo "🚀 EXAMPLES:"
    echo "    print_success \"Operation completed\""
    echo "    check_required_commands wget curl git"
    echo "    validate_directory \"/opt/myapp\" true"
    echo "    download_file \"https://example.com/file.txt\" \"local.txt\""
    echo "    install_package \"nginx\""
    echo "    ask_yes_no \"Continue with installation?\""
    echo ""
    echo "💡 INTEGRATION:"
    echo "    This library is designed to be sourced by other scripts."
    echo "    All functions are automatically exported for use in subshells."
    echo "    Variables like colors and symbols are globally available."
    echo ""
    echo "📖 CONFIGURATION:"
    echo "    DEFAULT_LOG_LEVEL     - Set logging verbosity (0-3)"
    echo "    DEFAULT_LOG_FILE      - Default log file location"
    echo "    DEFAULT_QUIET_MODE    - Suppress output (true/false)"
    echo "    DEFAULT_VERBOSE_MODE  - Enable verbose output (true/false)"
    echo ""
    
    pause "Press Enter to continue..."
    show_menu
}

### Show quick help ###
show_quick_help() {
    echo "Universal Helper Functions v${SCRIPT_VERSION}"
    echo "Usage: $0 [--help|--version]"
    echo "Try '$0 --help' for more information."
}

### Show version information ###
show_version() {
    echo "Universal Helper Functions v${SCRIPT_VERSION}"
    echo "Complete utility library for bash scripts"
    echo "Copyright (c) 2025 Mawage (Development Team)"
    echo "License: MIT"
}

################################################################################
### === MAIN EXECUTION === ###
################################################################################

### Parse command line arguments ###
parse_arguments() {
    case "${1:-}" in
        -h|--help)
            show_help_documentation
            exit 0
            ;;
        -V|--version)
            show_version
            exit 0
            ;;
        "")
            ### No arguments - show interactive menu ###
            show_menu
            ;;
        *)
            ### Unknown argument - show quick help ###
            print_error "Unknown option: $1"
            echo ""
            show_quick_help
            exit 1
            ;;
    esac
}

### Main function ###
main() {
    ### Parse command line arguments ###
    parse_arguments "$@"
}

### Initialize when run directly ###
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    ### Running directly ###
    main "$@"
else
    ### Being sourced - just load functions ###
    if [ "$DEFAULT_VERBOSE_MODE" = "true" ]; then
        print_success "Helper functions v${SCRIPT_VERSION} loaded successfully"
        print_info "Type 'show_menu' for interactive menu"
    fi
fi