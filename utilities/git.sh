#!/bin/bash
################################################################################
### Project Workflow Manager - Universal File Header Management
### Manages file headers, versions, and automated commits
################################################################################
### Project: Universal Workflow System
### Version: 1.0.0
### Author:  Mawage (Workflow Team)
### Date:    2025-08-20
### License: MIT
### Usage:   Source this file and use workflow functions
################################################################################

SCRIPT_VERSION="2.0.0"
COMMIT="Complete Git Workflow and Version Management System"
clear


################################################################################
### === INITIALIZATION === ###
################################################################################

### Load project configuration and helper functions ###
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
    
    ### Now all variables from project.conf are available ###
    if [ ! -f "$HELPER_SCRIPT" ]; then
        echo "ERROR: Helper script not found: $HELPER_SCRIPT"
        exit 1
    fi
    source "$HELPER_SCRIPT"
    
    print_info "Loaded project config: $PROJECT_NAME"
}


################################################################################
### === VERSION MANAGEMENT === ###
################################################################################

### Extract version from file - prioritize SCRIPT_VERSION variable ###
get_file_version() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo "0.0.0"
        return 1
    fi
    
    ### First try to get SCRIPT_VERSION variable ###
    local script_version=$(grep "^SCRIPT_VERSION=" "$file" | head -1 | cut -d'"' -f2)
    
    if [ -n "$script_version" ] && [ "$script_version" != "" ]; then
        echo "$script_version"
    else
        ### Fallback to header comment if variable not found ###
        grep "^### Version:" "$file" | head -1 | sed 's/.*Version: *//' || echo "0.0.0"
    fi
}

### Increment version number ###
auto_version() {
    local current_version="$1"
    local increment_type="${2:-patch}"  # major, minor, patch
    
    if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "1.0.0"
        return 0
    fi
    
    local major=$(echo "$current_version" | cut -d. -f1)
    local minor=$(echo "$current_version" | cut -d. -f2)
    local patch=$(echo "$current_version" | cut -d. -f3)
    
    case "$increment_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch|*)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "$major.$minor.$patch"
}


################################################################################
### === HEADER UPDATE FUNCTIONS === ###
################################################################################

### Update file header ###
update_header() {
    local file="$1"
    local new_commit="${2:-Auto update}"
    local increment_type="${3:-patch}"
    
    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi
    
    ### Get current version - now using single function ###
    local current_version=$(get_file_version "$file")
    
    ### Calculate new version ###
    local new_version=$(auto_version "$current_version" "$increment_type")
    local current_date=$(date +%Y-%m-%d)
    
    ### Create temporary file ###
    local temp_file=$(mktemp)
    
    ### Update header section ###
    awk -v new_version="$new_version" -v new_date="$current_date" -v new_commit="$new_commit" '
    BEGIN { in_header = 0; header_done = 0 }
    
    # Start of header
    /^################################################################################$/ && !header_done {
        if (in_header == 0) {
            in_header = 1
            print $0
        } else {
            in_header = 0
            header_done = 1
            print $0
        }
        next
    }
    
    # Inside header - update specific lines
    in_header == 1 {
        if (/^### Version:/) {
            print "### Version: " new_version
        } else if (/^### Date:/) {
            print "### Date:    " new_date
        } else {
            print $0
        }
        next
    }
    
    # Update SCRIPT_VERSION variable
    /^SCRIPT_VERSION=/ && header_done {
        print "SCRIPT_VERSION=\"" new_version "\""
        next
    }
    
    # Update COMMIT variable
    /^COMMIT=/ && header_done {
        print "COMMIT=\"" new_commit "\""
        next
    }
    
    # All other lines
    { print $0 }
    ' "$file" > "$temp_file"
    
    ### Replace original file ###
    if mv "$temp_file" "$file"; then
        print_success "Updated $file to version $new_version"
        echo "  Version: $current_version → $new_version"
        echo "  Date: $current_date"
        echo "  Commit: $new_commit"
        return 0
    else
        print_error "Failed to update $file"
        rm -f "$temp_file"
        return 1
    fi
}


################################################################################
### === GIT INTEGRATION === ###
################################################################################

### Commit with automatic header update ###
commit_update() {
    local file="$1"
    local commit_message="$2"
    local increment_type="${3:-patch}"
    
    if [ -z "$file" ] || [ -z "$commit_message" ]; then
        echo "Usage: commit_update <file> <commit_message> [increment_type]"
        echo "  increment_type: major, minor, patch (default: patch)"
        return 1
    fi
    
    ### Update header first ###
    if ! update_header "$file" "$commit_message" "$increment_type"; then
        print_error "Header update failed"
        return 1
    fi
    
    ### Get commit message from file (use COMMIT variable) ###
    local actual_commit_message
    if grep -q "^COMMIT=" "$file"; then
        actual_commit_message=$(grep "^COMMIT=" "$file" | cut -d'"' -f2)
    else
        actual_commit_message="$commit_message"
    fi
    
    ### Git operations ###
    git add "$file"
    
    if git commit -m "$actual_commit_message"; then
        local new_version=$(get_file_version "$file")
        print_success "Committed $file v$new_version"
        return 0
    else
        print_error "Git commit failed"
        return 1
    fi
}

### Batch update multiple files ###
batch_update() {
    local commit_message="$1"
    local increment_type="${2:-patch}"
    shift 2
    local files=("$@")
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "Usage: batch_update <commit_message> [increment_type] <file1> [file2] ..."
        return 1
    fi
    
    print_info "Batch updating ${#files[@]} files..."
    
    local updated_files=()
    local failed_files=()
    
    ### Update all files ###
    for file in "${files[@]}"; do
        if update_header "$file" "$commit_message" "$increment_type"; then
            updated_files+=("$file")
        else
            failed_files+=("$file")
        fi
    done
    
    ### Commit all updated files ###
    if [ ${#updated_files[@]} -gt 0 ]; then
        git add "${updated_files[@]}"
        
        if git commit -m "$commit_message"; then
            print_success "Batch commit successful: ${#updated_files[@]} files"
            for file in "${updated_files[@]}"; do
                local version=$(get_file_version "$file")
                echo "  ✓ $file v$version"
            done
        else
            print_error "Batch commit failed"
        fi
    fi
    
    ### Report failures ###
    if [ ${#failed_files[@]} -gt 0 ]; then
        print_warning "Failed to update: ${failed_files[*]}"
    fi
}


################################################################################
### === STATUS AND INFORMATION === ###
################################################################################

### Show file status ###
file_status() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi
    
    local version=$(get_file_version "$file")
    local commit_msg=""
    
    if grep -q "^COMMIT=" "$file"; then
        commit_msg=$(grep "^COMMIT=" "$file" | cut -d'"' -f2)
    fi
    
    echo "=== File Status: $file ==="
    echo "Version:        $version"
    echo "Commit Message: $commit_msg"
    echo "Last Modified:  $(stat -c %y "$file" 2>/dev/null || echo "unknown")"
}

### Show all tracked files status ###
project_files() {
    print_info "Project Files Status:"
    
    ### Find files with headers ###
    local files=($(find . -name "*.sh" -exec grep -l "SCRIPT_VERSION=" {} \; 2>/dev/null))
    
    for file in "${files[@]}"; do
        local version=$(get_file_version "$file")
        printf "  %-20s v%s\n" "$(basename "$file")" "$version"
    done
}


################################################################################
### === BRANCH MANAGEMENT === ###
################################################################################

### Setup branch structure ###
setup_branches() {
    print_info "Setting up branch structure..."
    
    local main_branch="${REPO_BRANCH:-main}"
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    
    ### Ensure main branch exists ###
    git checkout "$main_branch" 2>/dev/null || git checkout -b "$main_branch"
    
    ### Create develop branch if needed ###
    if ! git show-ref --verify --quiet "refs/heads/$develop_branch"; then
        git checkout -b "$develop_branch"
        print_success "Created $develop_branch branch"
    else
        print_info "$develop_branch branch already exists"
    fi
    
    ### Set upstream tracking ###
    git branch --set-upstream-to="origin/$main_branch" "$main_branch" 2>/dev/null || true
    git branch --set-upstream-to="origin/$develop_branch" "$develop_branch" 2>/dev/null || true
    
    git checkout "$develop_branch"
    print_success "Branch structure ready"
}

### Start feature branch ###
start_feature() {
    local feature_name="$1"
    
    if [ -z "$feature_name" ]; then
        echo "Usage: start_feature <feature_name>"
        echo "Example: start_feature enhanced-validation"
        return 1
    fi
    
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    local feature_prefix="${FEATURE_BRANCH_PREFIX:-feature/}"
    local branch_name="${feature_prefix}${feature_name}"
    
    ### Switch to develop and update ###
    git checkout "$develop_branch"
    git pull origin "$develop_branch" 2>/dev/null || true
    
    ### Create feature branch ###
    git checkout -b "$branch_name"
    
    print_success "Created feature branch: $branch_name"
    print_info "Work on your feature, then run: finish_feature $feature_name"
}

### Finish feature branch ###
finish_feature() {
    local feature_name="$1"
    
    if [ -z "$feature_name" ]; then
        echo "Usage: finish_feature <feature_name>"
        return 1
    fi
    
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    local feature_prefix="${FEATURE_BRANCH_PREFIX:-feature/}"
    local branch_name="${feature_prefix}${feature_name}"
    local current_branch=$(git branch --show-current)
    
    ### Ensure we're on the feature branch ###
    if [ "$current_branch" != "$branch_name" ]; then
        git checkout "$branch_name" || {
            print_error "Feature branch $branch_name not found"
            return 1
        }
    fi
    
    ### Merge back to develop ###
    git checkout "$develop_branch"
    git merge "$branch_name" --no-ff -m "Merge feature: $feature_name"
    
    ### Delete feature branch ###
    git branch -d "$branch_name"
    
    print_success "Feature $feature_name merged and cleaned up"
}

################################################################################
### === TAG AND RELEASE MANAGEMENT === ###
################################################################################

### Create version tag ###
create_tag() {
    local version="$1"
    local message="$2"
    
    if [ -z "$version" ]; then
        echo "Usage: create_tag <version> [message]"
        echo "Example: create_tag v1.2.3 'Release with new features'"
        return 1
    fi
    
    ### Add version prefix if needed ###
    if [[ ! "$version" =~ ^v[0-9] ]]; then
        version="${VERSION_PREFIX:-v}$version"
    fi
    
    ### Validate version format ###
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format. Use vX.Y.Z (e.g., v1.2.3)"
        return 1
    fi
    
    ### Check if tag exists ###
    if git tag -l | grep -q "^$version$"; then
        print_error "Tag $version already exists"
        return 1
    fi
    
    ### Create annotated tag ###
    local tag_message="${message:-Release $version}"
    git tag -a "$version" -m "$tag_message"
    
    print_success "Created tag: $version"
    print_info "Message: $tag_message"
    
    return 0
}

### Create release ###
create_release() {
    local version="$1"
    local message="$2"
    
    if [ -z "$version" ]; then
        echo "Usage: create_release <version> [message]"
        echo "Example: create_release v1.2.3 'Major feature release'"
        return 1
    fi
    
    local main_branch="${REPO_BRANCH:-main}"
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    
    print_info "Creating release $version..."
    
    ### Ensure we're on develop ###
    git checkout "$develop_branch"
    
    ### Merge to main ###
    git checkout "$main_branch"
    git merge "$develop_branch" --no-ff -m "Release $version"
    
    ### Create tag ###
    create_tag "$version" "$message"
    
    ### Back to develop ###
    git checkout "$develop_branch"
    
    print_success "Release $version created!"
    
    ### Ask to push ###
    if ask_yes_no "Push release to remote?" "yes"; then
        push_changes "true"
    fi
}

################################################################################
### === SYNCHRONIZATION === ###
################################################################################

### Push changes to remote ###
push_changes() {
    local push_tags="${1:-false}"
    local branch=$(git branch --show-current)
    
    print_info "Pushing $branch to remote..."
    
    if git push origin "$branch" 2>/dev/null; then
        print_success "Pushed $branch branch"
    else
        print_warning "Could not push $branch branch"
        return 1
    fi
    
    if [ "$push_tags" = "true" ] || [ "$push_tags" = "yes" ]; then
        if git push origin --tags 2>/dev/null; then
            print_success "Pushed tags"
        else
            print_warning "Could not push tags"
        fi
    fi
    
    return 0
}

### Sync with remote ###
sync_remote() {
    local branch=$(git branch --show-current)
    
    print_info "Syncing $branch with remote..."
    
    ### Fetch latest changes ###
    git fetch origin 2>/dev/null || {
        print_warning "Could not fetch from remote"
        return 1
    }
    
    ### Pull changes ###
    if git pull origin "$branch" 2>/dev/null; then
        print_success "Pulled latest changes"
    else
        print_warning "Could not pull changes"
    fi
    
    ### Push local changes ###
    push_changes
}

### Repository health check ###
repo_health() {
    print_header "Repository Health Check"
    
    local issues=0
    
    ### Check if in git repo ###
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi
    print_check "Git repository detected"
    
    ### Check remote ###
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_cross "No remote 'origin' configured"
        ((issues++))
    else
        print_check "Remote 'origin' configured"
    fi
    
    ### Check user config ###
    local user_name=$(git config user.name 2>/dev/null)
    local user_email=$(git config user.email 2>/dev/null)
    
    if [ -z "$user_name" ]; then
        print_cross "Git user.name not configured"
        ((issues++))
    else
        print_check "Git user.name: $user_name"
    fi
    
    if [ -z "$user_email" ]; then
        print_cross "Git user.email not configured"
        ((issues++))
    else
        print_check "Git user.email: $user_email"
    fi
    
    ### Check for uncommitted changes ###
    if ! git diff --quiet 2>/dev/null; then
        print_warning "Uncommitted changes in working directory"
        ((issues++))
    else
        print_check "Working directory clean"
    fi
    
    echo ""
    if [ $issues -eq 0 ]; then
        print_success "Repository health: EXCELLENT ✨"
    elif [ $issues -le 2 ]; then
        print_warning "Repository health: GOOD (${issues} minor issues)"
    else
        print_error "Repository health: NEEDS ATTENTION (${issues} issues)"
    fi
    
    return $issues
}


################################################################################
### === MENU AND HELP === ###
################################################################################

### Workflow Menu ###
show_menu() {
    print_header "Git Workflow Manager - Complete Help"
    
    echo "📝 FILE & VERSION MANAGEMENT:"
    echo "  update_header <file> [commit] [type]    - Update file header with version"
    echo "  commit_update <file> <commit> [type]    - Update header and commit"
    echo "  batch_update <commit> [type] <files...> - Update multiple files at once"
    echo ""
    
    echo "🌿 BRANCH MANAGEMENT:"
    echo "  setup_branches                          - Setup main/develop structure"
    echo "  start_feature <name>                    - Create new feature branch"
    echo "  finish_feature <name>                   - Merge feature back to develop"
    echo ""
    
    echo "🏷️ RELEASE & TAGS:"
    echo "  create_tag <version> [message]          - Create version tag"
    echo "  create_release <version> [message]      - Full release process"
    echo ""
    
    echo "🔄 SYNCHRONIZATION:"
    echo "  push_changes [push_tags]                - Push to remote repository"
    echo "  sync_remote                             - Full sync with remote"
    echo ""
    
    echo "📊 STATUS & INFORMATION:"
    echo "  file_status <file>                      - Show file version details"
    echo "  project_files                           - List all versioned files"
    echo "  repo_health                             - Complete repository health check"
    echo ""
    
    echo "📌 COMMAND LINE OPTIONS:"
    echo "  -h, --help                              - Show this help menu"
    echo "  -g, --git [file]                        - Show git repo or file info"
    echo "  -s, --status [file]                     - Show project or file status"
    echo "  -u, --update <file> <msg> [type]        - Update and commit file"
    echo "  -b, --batch <msg> [type] <files...>     - Batch update files"
    echo "  -f, --feature <name>                    - Start new feature branch"
    echo "  -r, --release <version> [message]       - Create new release"
    echo "  --health                                - Run repository health check"
    echo "  --sync                                  - Synchronize with remote"
    echo "  -v, --version                           - Show script version"
    echo ""
    
    echo "EXAMPLES:"
    echo "  $0 --feature user-authentication        - Start new feature branch"
    echo "  $0 --release v2.0.0 'Major release'     - Create and tag release"
    echo "  $0 --health                             - Check repository health"
    echo "  $0 --sync                               - Sync with remote repository"
}


################################################################################
### === MAIN EXECUTION === ###
################################################################################

### Parse command line arguments ###
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_menu
                exit 0
                ;;

            -g|--git)
                shift
                if [ -n "$1" ] && [ ! "$1" = -* ]; then
                    ### File specific git info ###
                    show_git_file_info "$1"
                else
                    ### General repository info ###
                    show_git_repo_info
                fi
                exit 0
                ;;

            -s|--status)
                shift
                if [ -n "$1" ] && [ ! "$1" = -* ]; then
                    file_status "$1"
                else
                    project_files
                fi
                exit 0
                ;;

            -u|--update)
                shift
                if [ -z "$1" ] || [ -z "$2" ]; then
                    echo "Usage: $0 --update <file> <commit_message> [version_type]"
                    exit 1
                fi
                local file="$1"
                local message="$2"
                local type="${3:-patch}"
                commit_update "$file" "$message" "$type"
                exit 0
                ;;

            -b|--batch)
                shift
                if [ -z "$1" ]; then
                    echo "Usage: $0 --batch <commit_message> [version_type] <files...>"
                    exit 1
                fi
                batch_update "$@"
                exit 0
                ;;

            -v|--version)
                echo "GitWork Version: $SCRIPT_VERSION"
                exit 0
                ;;

            -f|--feature)
                shift
                if [ -z "$1" ]; then
                    echo "Usage: $0 --feature <feature_name>"
                    exit 1
                fi
                start_feature "$1"
                exit 0
                ;;

            -r|--release)
                shift
                if [ -z "$1" ]; then
                    echo "Usage: $0 --release <version> [message]"
                    exit 1
                fi
                create_release "$1" "$2"
                exit 0
                ;;

            --health)
                repo_health
                exit 0
                ;;

            --sync)
                sync_remote
                exit 0
                ;;

            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;

        esac
        shift
    done
}

### Show git repository information ###
show_git_repo_info() {
    print_header "Git Repository Information"
    
    ### Check if we're in a git repository ###
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi
    
    ### Basic info ###
    print_info "Repository Status:"
    echo "  Branch:        $(git branch --show-current)"
    echo "  Remote:        $(git remote get-url origin 2>/dev/null || echo 'No remote')"
    echo "  Last Commit:   $(git log -1 --format='%h - %s' 2>/dev/null || echo 'No commits')"
    echo "  Author:        $(git log -1 --format='%an <%ae>' 2>/dev/null || echo 'Unknown')"
    echo "  Date:          $(git log -1 --format='%cd' --date=short 2>/dev/null || echo 'Unknown')"
    echo ""
    
    ### Working tree status ###
    print_info "Working Tree:"
    local modified=$(git status --porcelain | grep -c "^ M" || echo "0")
    local untracked=$(git status --porcelain | grep -c "^??" || echo "0")
    local staged=$(git status --porcelain | grep -c "^[AM]" || echo "0")
    
    echo "  Modified:      $modified files"
    echo "  Untracked:     $untracked files"
    echo "  Staged:        $staged files"
    echo ""
    
    ### Remote status ###
    if git remote show origin >/dev/null 2>&1; then
        print_info "Remote Status:"
        git fetch --dry-run 2>&1 | grep -q "up to date" && echo "  Status:        Up to date" || echo "  Status:        Updates available"
        
        local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        
        echo "  Ahead:         $ahead commits"
        echo "  Behind:        $behind commits"
    fi
}

### Show git file information ###
show_git_file_info() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        exit 1
    fi
    
    print_header "Git File Information: $(basename $file)"
    
    ### Check if file is tracked ###
    if ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        print_warning "File is not tracked by git"
        echo ""
    fi
    
    ### File version info ###
    print_info "Version Information:"
    local version=$(get_file_version "$file")
    echo "  Current Version: $version"
    
    if grep -q "^COMMIT=" "$file"; then
        local commit_msg=$(grep "^COMMIT=" "$file" | cut -d'"' -f2)
        echo "  Commit Message:  $commit_msg"
    fi
    echo ""
    
    ### Git history ###
    print_info "Git History:"
    echo "  Last Modified:   $(git log -1 --format='%cd' --date=short -- "$file" 2>/dev/null || echo 'Never')"
    echo "  Last Author:     $(git log -1 --format='%an' -- "$file" 2>/dev/null || echo 'Unknown')"
    echo "  Last Commit:     $(git log -1 --format='%h - %s' -- "$file" 2>/dev/null || echo 'No commits')"
    echo "  Total Commits:   $(git rev-list --count HEAD -- "$file" 2>/dev/null || echo '0')"
    echo ""
    
    ### File status ###
    print_info "File Status:"
    local status=$(git status --porcelain "$file" 2>/dev/null)
    if [ -z "$status" ]; then
        echo "  Status:          Clean"
    else
        case "${status:0:2}" in
            " M") echo "  Status:          Modified (not staged)" ;;
            "M ") echo "  Status:          Modified (staged)" ;;
            "MM") echo "  Status:          Modified (staged + unstaged changes)" ;;
            "A ") echo "  Status:          Added (staged)" ;;
            "??") echo "  Status:          Untracked" ;;
            *)    echo "  Status:          $status" ;;
        esac
    fi
    
    ### Show diff if modified ###
    if git status --porcelain "$file" 2>/dev/null | grep -q "^ M"; then
        echo ""
        print_info "Uncommitted changes:"
        git diff --stat "$file"
    fi
}

### Main function ###
main() {
    load_config
    
    if [ $# -eq 0 ]; then
        show_menu
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo "Try '$0 --help' for more information"
    else
        parse_arguments "$@"
    fi
}

### Initialize ###
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    ### Running directly ###
    main "$@"
else
    ### Being sourced ###
    load_config
    print_success "Workflow system loaded. Type 'show_menu' for help."
fi