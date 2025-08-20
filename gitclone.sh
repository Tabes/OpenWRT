#!/bin/bash
################################################################################
### OpenWRT Builder - Git Clone and Setup Script
### Clones the OpenWRT project and sets up permissions
################################################################################
### Version: 1.0.1
### Date:    2025-08-20
### Usage:   Run from any directory as root or with sudo
################################################################################

SCRIPT_VERSION="1.0.0"

set -e

################################################################################
### CONFIGURATION
################################################################################

### Project settings ###
PROJECT_URL="https://github.com/Tabes/OpenWRT.git"
TARGET_DIR="/opt/openWRT"
PROJECT_BRANCH="${PROJECT_BRANCH:-main}"

### Colors for output ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

### Symbols ###
SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"
INFO="ℹ️"
ARROW="➤"

################################################################################
### HELPER FUNCTIONS
################################################################################

### Print colored message ###
print_msg() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

### Print header ###
print_header() {
    echo ""
    print_msg "$BLUE" "################################################################################"
    print_msg "$BLUE" "### $1"
    print_msg "$BLUE" "################################################################################"
    echo ""
}

### Print step ###
print_step() {
    local step=$1
    shift
    print_msg "$CYAN" "${ARROW} Step $step: $*"
}

### Print success ###
print_success() {
    print_msg "$GREEN" "$SUCCESS $*"
}

### Print error ###
print_error() {
    print_msg "$RED" "$ERROR $*" >&2
}

### Print warning ###
print_warning() {
    print_msg "$YELLOW" "$WARNING $*"
}

### Print info ###
print_info() {
    print_msg "$WHITE" "$INFO $*"
}

### Error exit ###
error_exit() {
    print_error "$1"
    exit 1
}

### Check if running as root ###
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root or with sudo"
    fi
}

### Check if command exists ###
check_command() {
    local cmd="$1"
    local package="$2"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        print_warning "Command '$cmd' not found"
        if [ -n "$package" ]; then
            print_info "Installing $package..."
            apt update >/dev/null 2>&1
            apt install -y "$package" >/dev/null 2>&1
            print_success "Installed $package"
        else
            error_exit "Required command '$cmd' not available"
        fi
    fi
}

################################################################################
### SELF-UPDATE MECHANISM
################################################################################

### Extract version from script ###
get_script_version() {
    local script_file="$1"
    grep "^SCRIPT_VERSION=" "$script_file" 2>/dev/null | cut -d'"' -f2 || echo ""
}

### Combined version check ###
is_newer_version() {
    local current_script="$0"
    local project_script="$TARGET_DIR/gitclone.sh"
    
    if [ ! -f "$project_script" ]; then
        return 1
    fi
    
    ### First check: File timestamp ###
    local current_time=$(stat -c %Y "$current_script" 2>/dev/null || echo 0)
    local project_time=$(stat -c %Y "$project_script" 2>/dev/null || echo 0)
    
    ### Second check: Version number (if available) ###
    local current_version=$(get_script_version "$current_script")
    local project_version=$(get_script_version "$project_script")
    
    ### Check version number first (more reliable) ###
    if [ -n "$current_version" ] && [ -n "$project_version" ]; then
        if [ "$project_version" != "$current_version" ]; then
            print_info "Version update available:"
            print_info "  Current: v$current_version"
            print_info "  Project: v$project_version"
            return 0
        fi
    ### Fallback to timestamp if no version numbers ###
    elif [ "$project_time" -gt "$current_time" ]; then
        print_info "Newer file found (timestamp based):"
        print_info "  Current: $(date -d @$current_time '+%Y-%m-%d %H:%M:%S')"
        print_info "  Project: $(date -d @$project_time '+%Y-%m-%d %H:%M:%S')"
        return 0
    fi
    
    return 1
}

### Check for updated version in project ###
check_for_updates() {
    local project_script="$TARGET_DIR/gitclone.sh"
    local current_script="$0"
    
    ### Skip if we ARE the project version ###
    if [ "$(realpath "$current_script" 2>/dev/null)" = "$(realpath "$project_script" 2>/dev/null)" ]; then
        return 0
    fi
    
    ### Check if project version is newer ###
    if is_newer_version; then
        if [ "$FORCE_MODE" != "true" ] && [ "$QUIET_MODE" != "true" ]; then
            echo ""
            if ask_yes_no "Use updated version from project?" "yes"; then
                exec_updated_version "$project_script"
            else
                print_warning "Continuing with current version"
            fi
        elif [ "$FORCE_MODE" = "true" ]; then
            exec_updated_version "$project_script"
        fi
    fi
}

### Execute updated version ###
exec_updated_version() {
    local updated_script="$1"
    
    print_info "Switching to updated version..."
    print_info "Executing: $updated_script"
    
    ### Make sure it's executable ###
    chmod +x "$updated_script"
    
    ### Execute with all original arguments ###
    exec "$updated_script" "$@"
}

### Ask yes/no question ###
ask_yes_no() {
    local question="$1"
    local default="$2"
    
    local prompt="$question"
    case "$default" in
        yes|y) prompt="$prompt [Y/n]" ;;
        no|n)  prompt="$prompt [y/N]" ;;
        *)     prompt="$prompt [y/n]" ;;
    esac
    
    while true; do
        read -p "$prompt: " answer
        answer="${answer:-$default}"
        
        case "$answer" in
            yes|y|Y|YES) return 0 ;;
            no|n|N|NO)   return 1 ;;
            *) print_warning "Please answer yes or no" ;;
        esac
    done
}

################################################################################
### MAIN FUNCTIONS
################################################################################

### Remove existing installation ###
remove_existing() {
    if [ -d "$TARGET_DIR" ]; then
        print_warning "Existing installation found at $TARGET_DIR"
        print_info "Removing existing installation..."
        
        ### Stop any running processes that might use the directory ###
        if command -v fuser >/dev/null 2>&1; then
            fuser -k "$TARGET_DIR" 2>/dev/null || true
        fi
        
        ### Unmount any loop devices ###
        for loop in $(losetup -a 2>/dev/null | grep "$TARGET_DIR" | cut -d: -f1); do
            print_info "Detaching loop device: $loop"
            losetup -d "$loop" 2>/dev/null || true
        done
        
        ### Remove directory ###
        rm -rf "$TARGET_DIR"
        print_success "Removed existing installation"
    fi
}

### Clone repository ###
clone_repository() {
    print_info "Cloning repository from: $PROJECT_URL"
    print_info "Target directory: $TARGET_DIR"
    print_info "Branch: $PROJECT_BRANCH"
    
    ### Create parent directory ###
    mkdir -p "$(dirname "$TARGET_DIR")"
    
    ### Clone with progress ###
    if git clone --progress --branch "$PROJECT_BRANCH" "$PROJECT_URL" "$TARGET_DIR"; then
        print_success "Repository cloned successfully"
    else
        error_exit "Failed to clone repository"
    fi
}

### Set permissions ###
set_permissions() {
    print_info "Setting file permissions..."
    
    ### Set ownership ###
    chown -R root:root "$TARGET_DIR"
    print_success "Set ownership to root:root"
    
    ### Set directory permissions ###
    find "$TARGET_DIR" -type d -exec chmod 755 {} \;
    print_success "Set directory permissions (755)"
    
    ### Set file permissions ###
    find "$TARGET_DIR" -type f -exec chmod 644 {} \;
    print_success "Set file permissions (644)"
    
    ### Make scripts executable ###
    local script_dirs=(
        "$TARGET_DIR/builder"
        "$TARGET_DIR/builder/scripts"
        "$TARGET_DIR/builder/boot"
    )
    
    for dir in "${script_dirs[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -name "*.sh" -exec chmod +x {} \;
            print_success "Made scripts executable in: $(basename "$dir")"
        fi
    done
    
    ### Make main build script executable ###
    if [ -f "$TARGET_DIR/builder/build.sh" ]; then
        chmod +x "$TARGET_DIR/builder/build.sh"
        print_success "Made build.sh executable"
    fi
}

### Create symlinks ###
create_symlinks() {
    print_info "Creating configuration symlinks..."
    
    ### Global config symlink ###
    local global_config="$TARGET_DIR/builder/config/global.cfg"
    local target_config="$TARGET_DIR/config/global.cfg"
    
    if [ -f "$target_config" ]; then
        ### Remove existing symlink if present ###
        if [ -L "$global_config" ]; then
            rm -f "$global_config"
        fi
        
        ### Create new symlink ###
        cd "$TARGET_DIR/builder/config"
        ln -sf "../../config/global.cfg" "global.cfg"
        print_success "Created global.cfg symlink"
    else
        print_warning "Global config not found, skipping symlink creation"
    fi
}

### Validate installation ###
validate_installation() {
    print_info "Validating installation..."
    
    ### Check required directories ###
    local required_dirs=(
        "$TARGET_DIR/builder"
        "$TARGET_DIR/builder/scripts"
        "$TARGET_DIR/builder/config"
        "$TARGET_DIR/config"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_success "Found: $(basename "$dir")"
        else
            print_error "Missing: $dir"
            return 1
        fi
    done
    
    ### Check key scripts ###
    local key_scripts=(
        "$TARGET_DIR/builder/build.sh"
        "$TARGET_DIR/builder/scripts/helper.sh"
        "$TARGET_DIR/builder/scripts/detect-media.sh"
        "$TARGET_DIR/builder/scripts/write-media.sh"
        "$TARGET_DIR/builder/scripts/debian-luci.sh"
    )
    
    for script in "${key_scripts[@]}"; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            print_success "Executable: $(basename "$script")"
        elif [ -f "$script" ]; then
            print_warning "Not executable: $(basename "$script")"
        else
            print_error "Missing: $(basename "$script")"
            return 1
        fi
    done
    
    print_success "Installation validation passed"
}

### Show installation summary ###
show_summary() {
    print_header "INSTALLATION SUMMARY"
    
    ### Project information ###
    print_info "Project Details:"
    echo "  • Repository: $PROJECT_URL"
    echo "  • Branch:     $PROJECT_BRANCH"
    echo "  • Location:   $TARGET_DIR"
    echo ""
    
    ### Git information ###
    if [ -d "$TARGET_DIR/.git" ]; then
        cd "$TARGET_DIR"
        local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        local commit_date=$(git log -1 --format="%cd" --date=short 2>/dev/null || echo "unknown")
        local commit_msg=$(git log -1 --format="%s" 2>/dev/null || echo "unknown")
        
        print_info "Git Information:"
        echo "  • Commit:     $commit_hash"
        echo "  • Date:       $commit_date"
        echo "  • Message:    $commit_msg"
        echo ""
    fi
    
    ### Directory structure ###
    print_info "Directory Structure:"
    if command -v tree >/dev/null 2>&1; then
        tree -L 2 "$TARGET_DIR" 2>/dev/null || ls -la "$TARGET_DIR"
    else
        ls -la "$TARGET_DIR"
    fi
    echo ""
    
    ### Usage instructions ###
    print_info "Next Steps:"
    echo "  1. Test device detection:"
    echo "     sudo $TARGET_DIR/builder/scripts/detect-media.sh"
    echo ""
    echo "  2. Start a build:"
    echo "     sudo $TARGET_DIR/builder/build.sh"
    echo ""
    echo "  3. Get help:"
    echo "     sudo $TARGET_DIR/builder/build.sh --help"
    echo ""
    
    print_success "OpenWRT Builder is ready to use!"
}

################################################################################
### MAIN EXECUTION
################################################################################

### Show usage ###
show_usage() {
    print_header "OpenWRT Builder - Git Clone Setup"
    
    echo "USAGE:"
    echo "    sudo $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "    -h, --help      Show this help message"
    echo "    -b, --branch    Specify git branch (default: main)"
    echo "    -f, --force     Force overwrite without confirmation"
    echo "    -q, --quiet     Quiet mode (minimal output)"
    echo ""
    echo "EXAMPLES:"
    echo "    sudo $0                   # Standard installation"
    echo "    sudo $0 -b develop        # Install develop branch"
    echo "    sudo $0 -f                # Force overwrite"
    echo ""
    echo "DESCRIPTION:"
    echo "    This script will:"
    echo "    • Remove any existing installation"
    echo "    • Clone the OpenWRT project from GitHub"
    echo "    • Set proper file permissions"
    echo "    • Create configuration symlinks"
    echo "    • Validate the installation"
    echo ""
}

### Parse command line arguments ###
FORCE_MODE=false
QUIET_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -b|--branch)
            PROJECT_BRANCH="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_MODE=true
            shift
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

### Main function ###
main() {
    ### Show header ###
    if [ "$QUIET_MODE" != "true" ]; then
        print_header "OpenWRT Builder - Git Clone Setup v$SCRIPT_VERSION"
    fi
    
    ### Check for updates BEFORE doing anything else ###
    check_for_updates
    
    ### Check prerequisites ###
    check_root
    check_command "git" "git"
    
    ### Show what will be done ###
    if [ "$QUIET_MODE" != "true" ]; then
        print_info "This script will:"
        echo "  • Remove existing installation (if any)"
        echo "  • Clone OpenWRT project from GitHub"
        echo "  • Set proper permissions"
        echo "  • Create configuration links"
        echo "  • Validate installation"
        echo ""
        
        if [ "$FORCE_MODE" != "true" ]; then
            read -p "Continue? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                exit 0
            fi
        fi
    fi
    
    ### Execute installation steps ###
    print_step "1" "Removing existing installation"
    remove_existing
    
    print_step "2" "Cloning repository"
    clone_repository
    
    print_step "3" "Setting permissions"
    set_permissions
    
    print_step "4" "Creating symlinks"
    create_symlinks
    
    print_step "5" "Validating installation"
    validate_installation
    
    ### Show summary ###
    if [ "$QUIET_MODE" != "true" ]; then
        show_summary
    else
        print_success "OpenWRT Builder installed successfully at $TARGET_DIR"
    fi
}

### Run main function ###
main "$@"