#!/bin/bash
################################################################################
### OpenWRT Builder - Git Clone and Setup Script
### Clones the OpenWRT project and sets up permissions
################################################################################
### Version: 1.0.5
### Date:    2025-08-20
### Usage:   Run from any directory as root or with sudo
################################################################################

SCRIPT_VERSION="1.0.5"
clear

################################################################################
### SAFETY: Ensure we're in a safe directory before anything else
################################################################################

### If we're being executed, immediately restart from root directory ###
if [ "${PWD}" != "/" ] && [ "${GITCLONE_RESTARTED:-}" != "true" ]; then
    export GITCLONE_RESTARTED="true"
    cd / && exec "$0" "$@"
    # If we get here, something went wrong
    echo "ERROR: Cannot change to safe directory"
    exit 1
fi

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

### Global status variables ###
TARGET_DIR_STATUS=""
INSTALLATION_TYPE=""

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
### DIRECTORY STATUS CHECK
################################################################################

### Check target directory status and set global variables ###
check_target_directory() {
    print_info "Checking target directory: $TARGET_DIR"
    
    ### Case 1: Directory doesn't exist - prepare for fresh installation ###
    if [ ! -d "$TARGET_DIR" ]; then
        print_info "Target directory does not exist - preparing for fresh installation"
        
        ### Create parent directory and set permissions ###
        if ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
            error_exit "Cannot create target directory: $TARGET_DIR"
        fi
        
        ### Ensure proper ownership of directory ###
        chown root:root "$TARGET_DIR" 2>/dev/null || true
        
        TARGET_DIR_STATUS="FRESH"
        INSTALLATION_TYPE="fresh"
        print_success "Prepared for fresh installation"
        return 0
    fi
    
    ### Case 2: Directory exists but is not a git repository ###
    if [ ! -d "$TARGET_DIR/.git" ]; then
        print_warning "Target directory exists but is not a git repository"
        TARGET_DIR_STATUS="INVALID"
        INSTALLATION_TYPE="overwrite"
        
        if [ "$FORCE_MODE" != "true" ]; then
            if ! ask_yes_no "Continue anyway? This will remove the existing directory" "no"; then
                error_exit "Installation cancelled"
            fi
        fi
        return 0
    fi
    
    ### Case 3: Directory exists and is a git repository - check if it's our project ###
    if [ -d "$TARGET_DIR/.git" ]; then
        cd "$TARGET_DIR"
        local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
        
        ### Check if it's our OpenWRT project ###
        if [[ "$remote_url" != *"OpenWRT"* ]]; then
            print_warning "Target directory contains a different git repository"
            print_info "Found: $remote_url"
            print_info "Expected: $PROJECT_URL"
            TARGET_DIR_STATUS="WRONG_REPO"
            INSTALLATION_TYPE="replace"
            
            if [ "$FORCE_MODE" != "true" ]; then
                if ! ask_yes_no "Continue anyway? This will replace the existing repository" "no"; then
                    error_exit "Installation cancelled"
                fi
            fi
            return 0
        fi
        
        ### It's our project - valid installation found ###
        TARGET_DIR_STATUS="VALID"
        INSTALLATION_TYPE="update"
        print_success "Valid OpenWRT installation found"
        return 0
    fi
    
    ### Fallback - should not reach here ###
    TARGET_DIR_STATUS="UNKNOWN"
    INSTALLATION_TYPE="unknown"
    print_warning "Unknown directory status"
    return 1
}

################################################################################
### GIT VERSION CHECKING
################################################################################

### Professional Git version checking function ###
check_git_version() {
    local repo_dir="$1"
    local script_file="$2"
    local branch="${3:-main}"
    local check_type="${4:-smart}"
    
    # Validate parameters
    if [ ! -d "$repo_dir" ]; then
        echo "ERROR: Repository directory not found: $repo_dir"
        return 3
    fi
    
    if [ ! -d "$repo_dir/.git" ]; then
        echo "ERROR: Not a git repository: $repo_dir"
        return 3
    fi
    
    cd "$repo_dir"
    
    # Quick network check
    if ! git ls-remote origin >/dev/null 2>&1; then
        echo "NETWORK_ERROR: Cannot reach remote repository"
        return 3
    fi
    
    case "$check_type" in
        "tags")
            _check_version_by_tags "$repo_dir" "$branch"
            ;;
        "commits")
            _check_version_by_commits "$repo_dir" "$branch"
            ;;
        "file")
            _check_file_version "$repo_dir" "$script_file" "$branch"
            ;;
        "smart"|*)
            _smart_version_check "$repo_dir" "$script_file" "$branch"
            ;;
    esac
}

### Tag-based version checking ###
_check_version_by_tags() {
    local repo_dir="$1"
    local branch="$2"
    cd "$repo_dir"
    
    # Fetch latest tags
    if ! git fetch --tags >/dev/null 2>&1; then
        echo "FETCH_ERROR: Cannot fetch tags"
        return 3
    fi
    
    # Get current tag (if on tagged commit)
    local current_tag=$(git describe --tags --exact-match HEAD 2>/dev/null || echo "")
    
    # Get latest tag
    local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    if [ -z "$latest_tag" ]; then
        echo "NO_TAGS: Repository has no version tags"
        return 2
    fi
    
    if [ -n "$current_tag" ]; then
        if [ "$current_tag" != "$latest_tag" ]; then
            echo "UPDATE_AVAILABLE: Tag update available"
            echo "CURRENT_VERSION: $current_tag"
            echo "LATEST_VERSION: $latest_tag"
            return 0
        else
            echo "UP_TO_DATE: On latest tag"
            echo "VERSION: $current_tag"
            return 1
        fi
    else
        echo "NOT_ON_TAG: Current commit is not tagged"
        echo "LATEST_TAG: $latest_tag"
        local commits_since=$(git rev-list --count $latest_tag..HEAD 2>/dev/null || echo "unknown")
        echo "COMMITS_SINCE_TAG: $commits_since"
        return 0
    fi
}

### Commit-based version checking ###
_check_version_by_commits() {
    local repo_dir="$1"
    local branch="$2"
    cd "$repo_dir"
    
    # Fetch latest commits
    if ! git fetch origin "$branch" >/dev/null 2>&1; then
        echo "FETCH_ERROR: Cannot fetch branch $branch"
        return 3
    fi
    
    # Compare hashes
    local local_hash=$(git rev-parse HEAD 2>/dev/null)
    local remote_hash=$(git rev-parse "origin/$branch" 2>/dev/null)
    
    if [ -z "$local_hash" ] || [ -z "$remote_hash" ]; then
        echo "HASH_ERROR: Cannot determine commit hashes"
        return 3
    fi
    
    if [ "$local_hash" != "$remote_hash" ]; then
        local commits_behind=$(git rev-list --count HEAD..origin/$branch 2>/dev/null || echo "unknown")
        echo "UPDATE_AVAILABLE: Commits available"
        echo "COMMITS_BEHIND: $commits_behind"
        echo "LOCAL_HASH: ${local_hash:0:8}"
        echo "REMOTE_HASH: ${remote_hash:0:8}"
        return 0
    else
        echo "UP_TO_DATE: On latest commit"
        echo "HASH: ${local_hash:0:8}"
        return 1
    fi
}

### File-specific version checking ###
_check_file_version() {
    local repo_dir="$1"
    local file_path="$2"
    local branch="$3"
    cd "$repo_dir"
    
    if [ ! -f "$file_path" ]; then
        echo "FILE_ERROR: File not found: $file_path"
        return 3
    fi
    
    # Fetch latest
    if ! git fetch origin "$branch" >/dev/null 2>&1; then
        echo "FETCH_ERROR: Cannot fetch branch $branch"
        return 3
    fi
    
    # Check if specific file changed
    local local_hash=$(git log -1 --format="%H" -- "$file_path" 2>/dev/null)
    local remote_hash=$(git log -1 --format="%H" "origin/$branch" -- "$file_path" 2>/dev/null)
    
    if [ -z "$local_hash" ] || [ -z "$remote_hash" ]; then
        echo "FILE_HASH_ERROR: Cannot determine file change history"
        return 3
    fi
    
    if [ "$local_hash" != "$remote_hash" ]; then
        echo "FILE_CHANGED: File has updates"
        echo "FILE: $file_path"
        local local_date=$(git log -1 --format="%cd" --date=short -- "$file_path" 2>/dev/null)
        local remote_date=$(git log -1 --format="%cd" --date=short "origin/$branch" -- "$file_path" 2>/dev/null)
        echo "LOCAL_CHANGE: $local_date"
        echo "REMOTE_CHANGE: $remote_date"
        return 0
    else
        echo "FILE_UNCHANGED: File is up to date"
        echo "FILE: $file_path"
        return 1
    fi
}

### Smart version checking with optimized fetching ###
_smart_version_check() {
    local repo_dir="$1"
    local script_file="$2"
    local branch="$3"
    cd "$repo_dir"
    
    # Optimize fetching: only fetch if needed (older than 5 minutes)
    local last_fetch=$(stat -c %Y .git/FETCH_HEAD 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local fetch_age=$((current_time - last_fetch))
    
    if [ $fetch_age -gt 300 ]; then
        if ! git fetch origin "$branch" >/dev/null 2>&1; then
            echo "FETCH_ERROR: Cannot fetch updates"
            return 3
        fi
    fi
    
    # Strategy 1: Try tag-based version checking first
    local tag_result=$(_check_version_by_tags "$repo_dir" "$branch" 2>/dev/null | head -1)
    
    if [[ "$tag_result" =~ ^(UPDATE_AVAILABLE|UP_TO_DATE): ]]; then
        echo "$tag_result"
        local tag_details=$(_check_version_by_tags "$repo_dir" "$branch" 2>/dev/null | tail -n +2)
        echo "$tag_details"
        return ${PIPESTATUS[0]}
    fi
    
    # Strategy 2: Fallback to commit comparison
    echo "FALLBACK: Using commit-based checking"
    _check_version_by_commits "$repo_dir" "$branch"
    local commit_result=$?
    
    # Strategy 3: If script file specified, also check file-specific changes
    if [ -n "$script_file" ] && [ -f "$script_file" ]; then
        echo "FILE_CHECK: Checking $script_file specifically"
        _check_file_version "$repo_dir" "$script_file" "$branch" | grep -E "^(FILE_CHANGED|FILE_UNCHANGED):"
    fi
    
    return $commit_result
}

################################################################################
### SELF-UPDATE MECHANISM
################################################################################

### Extract version from script ###
get_script_version() {
    local script_file="$1"
    grep "^SCRIPT_VERSION=" "$script_file" 2>/dev/null | cut -d'"' -f2 || echo ""
}

### Enhanced version check using git ###
is_newer_version() {
    local current_script="$0"
    local project_script="$TARGET_DIR/gitclone.sh"
    
    if [ ! -f "$project_script" ]; then
        return 1
    fi
    
    print_info "Using professional git version checking..."
    
    # Use our new git version checking function
    local git_result=$(check_git_version "$TARGET_DIR" "gitclone.sh" "$PROJECT_BRANCH" "file")
    
    # Parse result
    if echo "$git_result" | grep -q "FILE_CHANGED:"; then
        print_info "Git detected file changes:"
        echo "$git_result" | grep -E "^(FILE|LOCAL_CHANGE|REMOTE_CHANGE):" | sed 's/^/  /'
        return 0
    elif echo "$git_result" | grep -q "FILE_UNCHANGED:"; then
        print_info "Git confirms file is unchanged"
        return 1
    else
        # Fallback to traditional method
        print_warning "Git check inconclusive, using fallback method"
        _fallback_version_check "$current_script" "$project_script"
        return $?
    fi
}

### Fallback version check method ###
_fallback_version_check() {
    local current_script="$1"
    local project_script="$2"
    
    ### First check: File timestamp ###
    local current_time=$(stat -c %Y "$current_script" 2>/dev/null || echo 0)
    local project_time=$(stat -c %Y "$project_script" 2>/dev/null || echo 0)
    
    ### Second check: Version number (if available) ###
    local current_version=$(get_script_version "$current_script")
    local project_version=$(get_script_version "$project_script")
    
    ### Check version number first (more reliable) ###
    if [ -n "$current_version" ] && [ -n "$project_version" ]; then
        if [ "$project_version" != "$current_version" ]; then
            print_info "Version number difference detected:"
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

### Check for script updates ###
check_for_updates() {
    ### Only check for updates if we have a valid installation ###
    if [ "$TARGET_DIR_STATUS" != "VALID" ]; then
        print_info "No existing installation found - skipping update check"
        return 0
    fi
    
    print_info "Checking for script updates using git analysis..."
    
    ### Use git version checking for repository status ###
    local repo_status=$(check_git_version "$TARGET_DIR" "gitclone.sh" "$PROJECT_BRANCH" "commits")
    
    if echo "$repo_status" | grep -q "UPDATE_AVAILABLE:"; then
        print_info "Repository updates detected:"
        echo "$repo_status" | grep -E "^(COMMITS_BEHIND|LOCAL_HASH|REMOTE_HASH):" | sed 's/^/  /'
    elif echo "$repo_status" | grep -q "UP_TO_DATE:"; then
        print_info "Repository is up to date"
    else
        print_warning "Cannot determine repository status"
        print_info "$repo_status"
    fi
    
    local project_script="$TARGET_DIR/gitclone.sh"
    local current_script="$0"
    
    ### Skip if we ARE the project version ###
    if [ "$(realpath "$current_script" 2>/dev/null)" = "$(realpath "$project_script" 2>/dev/null)" ]; then
        print_info "Already using project version"
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
    else
        print_info "Script is up to date"
    fi
}

### Execute updated version ###
exec_updated_version() {
    local updated_script="$1"
    local current_script="$0"
    shift  # Remove first parameter (updated_script path)
    
    print_info "Switching to updated version..."
    print_info "Executing: $updated_script"
    
    ### Copy newer version to user directory for future use ###
    if [ "$updated_script" != "$current_script" ]; then
        print_info "Copying updated script to: $current_script"
        if cp "$updated_script" "$current_script" 2>/dev/null; then
            print_success "Updated script copied to user directory"
        else
            print_warning "Could not copy to user directory (continuing anyway)"
        fi
    fi
    
    ### Make sure it's executable ###
    chmod +x "$updated_script"
    
    ### Execute with remaining original arguments (without the script path) ###
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

### Enhanced clone repository with cleanup on failure ###
clone_repository() {
    print_info "Cloning repository from: $PROJECT_URL"
    print_info "Target directory: $TARGET_DIR"
    print_info "Branch: $PROJECT_BRANCH"
    
    ### Create parent directory ###
    mkdir -p "$(dirname "$TARGET_DIR")"
    
    ### Clone with progress and error handling ###
    if git clone --progress --branch "$PROJECT_BRANCH" "$PROJECT_URL" "$TARGET_DIR"; then
        print_success "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        
        ### Cleanup failed clone attempt ###
        if [ -d "$TARGET_DIR" ]; then
            print_info "Cleaning up failed installation..."
            rm -rf "$TARGET_DIR"
            print_success "Cleaned up incomplete installation"
        fi
        
        error_exit "Git clone failed - installation aborted"
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
    
    ### Make gitclone.sh executable ###
    if [ -f "$TARGET_DIR/gitclone.sh" ]; then
        chmod +x "$TARGET_DIR/gitclone.sh"
        print_success "Made gitclone.sh executable"
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
    echo "  • Type:       $INSTALLATION_TYPE"
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
    
    ### Check prerequisites ###
    check_root
    check_command "git" "git"
    
    ### Check target directory status FIRST ###
    check_target_directory
    
    ### Check for updates ONLY if we have a valid installation ###
    check_for_updates
    
    ### Show what will be done ###
    if [ "$QUIET_MODE" != "true" ]; then
        print_info "Installation type: $INSTALLATION_TYPE"
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
    
    ### Execute installation steps based on installation type ###
    case "$INSTALLATION_TYPE" in
        fresh|overwrite|replace)
            print_step "1" "Removing existing installation"
            remove_existing
            
            print_step "2" "Cloning repository"
            clone_repository
            ;;
        update)
            print_step "1" "Updating existing installation"
            cd "$TARGET_DIR"
            git fetch origin "$PROJECT_BRANCH"
            git reset --hard "origin/$PROJECT_BRANCH"
            print_success "Repository updated successfully"
            ;;
        *)
            error_exit "Unknown installation type: $INSTALLATION_TYPE"
            ;;
    esac
    
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