#!/bin/bash
################################################################################
### Git Workflow Manager - Complete Git Repository Management System
### Manages version control, branching, releases, and automated workflows
### Integrates with project configuration and helper functions
################################################################################
### Project: Git Workflow Manager
### Version: 1.0.0
### Author:  Mawage (Workflow Team)
### Date:    2025-08-23
### License: MIT
### Usage:   ./git.sh [OPTIONS] or source for functions
################################################################################

SCRIPT_VERSION="1.0.0"
COMMIT="Complete Git Workflow and Version Management System"

### Prevent multiple inclusion ###
if [ -n "$GIT_WORKFLOW_LOADED" ]; then
    return 0
fi
GIT_WORKFLOW_LOADED=1


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
    
    ### Now all variables from project.conf are available ###
    if [ ! -f "$HELPER_SCRIPT" ]; then
        echo "ERROR: Helper script not found: $HELPER_SCRIPT"
        exit 1
    fi
    source "$HELPER_SCRIPT"
    
    print_info "Loaded project config: $PROJECT_NAME"
}


################################################################################
### === GIT REPOSITORY SETUP === ###
################################################################################

### Initialize git repository if needed ###
init_git_repo() {
    local repo_dir="${1:-$PROJECT_ROOT}"
    
    if [ ! -d "$repo_dir/.git" ]; then
        print_info "Initializing git repository in $repo_dir"
        
        cd "$repo_dir" || error_exit "Cannot access directory: $repo_dir"
        
        ### Initialize repository ###
        git init || error_exit "Failed to initialize git repository"
        
        ### Configure git user if from project config ###
        if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
            git config user.name "$GIT_USER_NAME"
            git config user.email "$GIT_USER_EMAIL"
            print_success "Configured git user: $GIT_USER_NAME <$GIT_USER_EMAIL>"
        fi
        
        ### Add remote if configured ###
        if [ -n "$REPO_URL" ]; then
            git remote add "$REPO_REMOTE_NAME" "$REPO_URL" 2>/dev/null || true
            print_info "Added remote: $REPO_URL"
        fi
        
        ### Create initial commit ###
        git add .
        git commit -m "Initial commit" || print_warning "No files to commit"
        
        print_success "Git repository initialized"
    else
        print_info "Git repository already exists"
    fi
}

### Professional Git version checking ###
check_git_version() {
    local repo_dir="${1:-$PROJECT_ROOT}"
    local branch="${2:-$REPO_BRANCH}"
    local check_type="${3:-commits}"
    
    validate_directory "$repo_dir" false
    
    if [ ! -d "$repo_dir/.git" ]; then
        print_error "Not a git repository: $repo_dir"
        return 3
    fi
    
    cd "$repo_dir"
    
    ### Quick network check ###
    if ! git ls-remote origin >/dev/null 2>&1; then
        print_warning "Cannot reach remote repository"
        return 3
    fi
    
    ### Fetch latest changes ###
    git fetch origin "$branch" >/dev/null 2>&1 || {
        print_warning "Cannot fetch branch $branch"
        return 3
    }
    
    ### Compare local and remote ###
    local local_hash=$(git rev-parse HEAD 2>/dev/null)
    local remote_hash=$(git rev-parse "origin/$branch" 2>/dev/null)
    
    if [ -z "$local_hash" ] || [ -z "$remote_hash" ]; then
        print_error "Cannot determine commit hashes"
        return 3
    fi
    
    if [ "$local_hash" != "$remote_hash" ]; then
        local commits_behind=$(git rev-list --count HEAD..origin/$branch 2>/dev/null || echo "unknown")
        print_info "Updates available: $commits_behind commits behind"
        print_info "Local:  ${local_hash:0:8}"
        print_info "Remote: ${remote_hash:0:8}"
        return 0
    else
        print_success "Repository is up to date"
        print_info "Hash: ${local_hash:0:8}"
        return 1
    fi
}

### Clone repository with enhanced features ###
clone_repository() {
    local repo_url="${1:-$REPO_URL}"
    local target_dir="${2:-$PROJECT_ROOT}"
    local branch="${3:-$REPO_BRANCH}"
    
    if [ -z "$repo_url" ]; then
        error_exit "Repository URL not provided"
    fi
    
    print_header "Cloning Repository"
    print_info "URL: $repo_url"
    print_info "Target: $target_dir"
    print_info "Branch: $branch"
    
    ### Check target directory status ###
    local dir_status=$(check_target_directory "$target_dir")
    
    case "$dir_status" in
        INVALID|WRONG_REPO)
            if ! ask_yes_no "Remove existing directory and continue?" "no"; then
                error_exit "Cannot clone to existing directory"
            fi
            safe_delete "$target_dir" true
            ;;
        VALID)
            print_info "Valid repository exists, updating instead..."
            cd "$target_dir"
            git fetch origin "$branch"
            git reset --hard "origin/$branch"
            print_success "Repository updated successfully"
            return 0
            ;;
    esac
    
    ### Create parent directory ###
    mkdir -p "$(dirname "$target_dir")"
    
    ### Clone with progress ###
    if git clone --progress --branch "$branch" "$repo_url" "$target_dir"; then
        cd "$target_dir"
        print_success "Repository cloned successfully"
        
        ### Configure git user ###
        if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
            git config user.name "$GIT_USER_NAME"
            git config user.email "$GIT_USER_EMAIL"
            print_info "Configured git user"
        fi
        
        ### Set permissions if we have root access ###
        if is_root; then
            set_repository_permissions "$target_dir"
        fi
        
        return 0
    else
        print_error "Failed to clone repository"
        
        ### Cleanup failed attempt ###
        if [ -d "$target_dir" ]; then
            print_info "Cleaning up failed installation..."
            safe_delete "$target_dir" true
        fi
        
        error_exit "Git clone failed - installation aborted"
    fi
}

### Set repository permissions ###
set_repository_permissions() {
    local repo_dir="${1:-$PROJECT_ROOT}"
    
    print_info "Setting repository permissions..."
    
    ### Set ownership to current user or root ###
    local owner=$(whoami)
    if is_root && [ -n "$SUDO_USER" ]; then
        owner="$SUDO_USER"
    fi
    
    chown -R "$owner:$owner" "$repo_dir" 2>/dev/null || true
    print_success "Set ownership to $owner"
    
    ### Set directory permissions ###
    find "$repo_dir" -type d -exec chmod 755 {} \; 2>/dev/null
    print_success "Set directory permissions (755)"
    
    ### Set file permissions ###
    find "$repo_dir" -type f -exec chmod 644 {} \; 2>/dev/null
    print_success "Set file permissions (644)"
    
    ### Make scripts executable ###
    find "$repo_dir" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
    print_success "Made shell scripts executable"
}

### Validate repository installation ###
validate_installation() {
    local repo_dir="${1:-$PROJECT_ROOT}"
    
    print_header "Validating Installation"
    
    ### Check if directory exists ###
    validate_directory "$repo_dir" true
    
    ### Check if it's a git repository ###
    if [ ! -d "$repo_dir/.git" ]; then
        print_error "Not a git repository"
        return 1
    fi
    print_check "Valid git repository"
    
    ### Check remote configuration ###
    cd "$repo_dir"
    local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -n "$remote_url" ]; then
        print_check "Remote configured: $remote_url"
    else
        print_cross "No remote configured"
    fi
    
    ### Check current branch ###
    local current_branch=$(git branch --show-current 2>/dev/null || echo "")
    if [ -n "$current_branch" ]; then
        print_check "Current branch: $current_branch"
    else
        print_cross "No current branch"
    fi
    
    ### Check for required files from project.conf ###
    if [ -n "${REQUIRED_FILES[*]}" ]; then
        print_info "Checking required files..."
        for file in "${REQUIRED_FILES[@]}"; do
            if validate_file "$repo_dir/$file" false; then
                print_check "$(basename "$file")"
            else
                print_cross "Missing: $(basename "$file")"
                return 1
            fi
        done
    fi
    
    ### Check for required directories ###
    if [ -n "${REQUIRED_DIRS[*]}" ]; then
        print_info "Checking required directories..."
        for dir in "${REQUIRED_DIRS[@]}"; do
            if [ -d "$repo_dir/$dir" ]; then
                print_check "$(basename "$dir")"
            else
                print_cross "Missing: $(basename "$dir")"
                return 1
            fi
        done
    fi
    
    print_success "Installation validation passed"
    return 0
}

### Show installation summary ###
show_installation_summary() {
    local repo_dir="${1:-$PROJECT_ROOT}"
    
    print_header "Installation Summary"
    
    ### Project information ###
    print_section "Project Details"
    echo "  Repository: ${REPO_URL:-Unknown}"
    echo "  Branch:     ${REPO_BRANCH:-Unknown}"
    echo "  Location:   $repo_dir"
    echo ""
    
    ### Git information ###
    if [ -d "$repo_dir/.git" ]; then
        cd "$repo_dir"
        local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        local commit_date=$(git log -1 --format="%cd" --date=short 2>/dev/null || echo "unknown")
        local commit_msg=$(git log -1 --format="%s" 2>/dev/null || echo "unknown")
        
        print_section "Git Information"
        echo "  Commit:  $commit_hash"
        echo "  Date:    $commit_date"
        echo "  Message: $commit_msg"
        echo ""
    fi
    
    ### Repository status ###
    print_section "Repository Status"
    local status_output=$(cd "$repo_dir" && git status --porcelain 2>/dev/null)
    if [ -z "$status_output" ]; then
        print_success "Working tree is clean"
    else
        local modified=$(echo "$status_output" | grep -c "^ M" || echo "0")
        local untracked=$(echo "$status_output" | grep -c "^??" || echo "0")
        echo "  Modified files:  $modified"
        echo "  Untracked files: $untracked"
    fi
    
    print_success "Repository installation completed successfully!"
}


################################################################################
### === GIT COMMIT OPERATIONS === ###
################################################################################

### Commit File with updated Header ###
commit_with_update() {
    local file="$1"
    local commit_message="$2"
    local increment_type="${3:-patch}"
    
    if [ -z "$file" ] || [ -z "$commit_message" ]; then
        print_error "Usage: commit_with_update <file> <commit_message> [increment_type]"
        print_info "increment_type: major, minor, patch (default: patch)"
        return 1
    fi
    
    print_header "Commit with Header Update"
    
    ### Update header using helper function ###
    if ! header --update "$file" "$commit_message" "$increment_type" >/dev/null; then
        error_exit "Header update failed"
    fi
    
    ### Get actual commit message from file ###
    local actual_commit_message
    if grep -q "^COMMIT=" "$file"; then
        actual_commit_message=$(grep "^COMMIT=" "$file" | cut -d'"' -f2)
    else
        actual_commit_message="$commit_message"
    fi
    
    ### Stage and commit ###
    git add "$file" || error_exit "Failed to stage file"
    
    if git commit -m "$actual_commit_message"; then
        local new_version=$(header --get-version "$file")
        print_success "Committed $(basename "$file") v$new_version"
        print_info "Message: $actual_commit_message"
        return 0
    else
        error_exit "Git commit failed"
    fi
}

### Batch commit multiple files ###
batch_commit() {
    local commit_message="$1"
    local increment_type="${2:-patch}"
    shift 2
    local files=("$@")
    
    if [ ${#files[@]} -eq 0 ]; then
        print_error "No files specified for batch commit"
        return 1
    fi
    
    print_header "Batch Commit: ${#files[@]} files"
    
    ### Update all files using helper function ###
    if ! header --batch-update "$commit_message" "$increment_type" "${files[@]}"; then
        print_warning "Some files failed to update"
    fi
    
    ### Get successfully updated files ###
    local updated_files=()
    for file in "${files[@]}"; do
        if git diff --name-only "$file" 2>/dev/null | grep -q "$file"; then
            updated_files+=("$file")
        fi
    done
    
    if [ ${#updated_files[@]} -eq 0 ]; then
        print_warning "No files were updated"
        return 1
    fi
    
    ### Stage all updated files ###
    git add "${updated_files[@]}" || error_exit "Failed to stage files"
    
    ### Commit all files ###
    if git commit -m "$commit_message"; then
        print_success "Batch commit successful: ${#updated_files[@]} files"
        
        for file in "${updated_files[@]}"; do
            local version=$(header --get-version "$file")
            print_check "$(basename "$file") v$version"
        done
        
        return 0
    else
        error_exit "Batch commit failed"
    fi
}

################################################################################
### === BRANCH MANAGEMENT === ###
################################################################################

### Setup standard branch structure ###
setup_branch_structure() {
    print_header "Setting up Branch Structure"
    
    local main_branch="${REPO_BRANCH:-main}"
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    
    ### Ensure we're in a git repository ###
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error_exit "Not in a git repository"
    fi
    
    ### Create or switch to main branch ###
    if ! git show-ref --verify --quiet "refs/heads/$main_branch"; then
        git checkout -b "$main_branch" || error_exit "Failed to create $main_branch branch"
        print_success "Created $main_branch branch"
    else
        git checkout "$main_branch" || error_exit "Failed to switch to $main_branch"
        print_info "Switched to $main_branch branch"
    fi
    
    ### Create develop branch if needed ###
    if ! git show-ref --verify --quiet "refs/heads/$develop_branch"; then
        git checkout -b "$develop_branch" || error_exit "Failed to create $develop_branch branch"
        print_success "Created $develop_branch branch"
    else
        print_info "$develop_branch branch already exists"
    fi
    
    ### Set upstream tracking if remote exists ###
    if git remote get-url origin >/dev/null 2>&1; then
        git branch --set-upstream-to="origin/$main_branch" "$main_branch" 2>/dev/null || true
        git branch --set-upstream-to="origin/$develop_branch" "$develop_branch" 2>/dev/null || true
        print_info "Set upstream tracking"
    fi
    
    ### Switch back to develop ###
    git checkout "$develop_branch"
    print_success "Branch structure setup complete"
}

### Create feature branch ###
create_feature_branch() {
    local feature_name="$1"
    
    if [ -z "$feature_name" ]; then
        print_error "Usage: create_feature_branch <feature_name>"
        print_info "Example: create_feature_branch user-authentication"
        return 1
    fi
    
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    local feature_prefix="${FEATURE_BRANCH_PREFIX:-feature/}"
    local branch_name="${feature_prefix}${feature_name}"
    
    print_header "Creating Feature Branch: $branch_name"
    
    ### Ensure develop branch exists ###
    if ! git show-ref --verify --quiet "refs/heads/$develop_branch"; then
        print_warning "$develop_branch branch not found, creating it"
        git checkout -b "$develop_branch"
    else
        git checkout "$develop_branch"
        
        ### Update develop if remote exists ###
        if git remote get-url origin >/dev/null 2>&1; then
            print_info "Updating $develop_branch branch"
            git pull origin "$develop_branch" 2>/dev/null || print_warning "Could not pull latest changes"
        fi
    fi
    
    ### Create feature branch ###
    git checkout -b "$branch_name" || error_exit "Failed to create feature branch"
    
    print_success "Created and switched to feature branch: $branch_name"
    print_info "Work on your feature, then run: finish_feature_branch $feature_name"
}

### Merge feature branch back ###
finish_feature_branch() {
    local feature_name="$1"
    
    if [ -z "$feature_name" ]; then
        print_error "Usage: finish_feature_branch <feature_name>"
        return 1
    fi
    
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    local feature_prefix="${FEATURE_BRANCH_PREFIX:-feature/}"
    local branch_name="${feature_prefix}${feature_name}"
    local current_branch=$(git branch --show-current)
    
    print_header "Finishing Feature Branch: $branch_name"
    
    ### Ensure we're on the feature branch or switch to it ###
    if [ "$current_branch" != "$branch_name" ]; then
        if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
            error_exit "Feature branch $branch_name not found"
        fi
        git checkout "$branch_name" || error_exit "Failed to switch to feature branch"
    fi
    
    ### Switch to develop ###
    git checkout "$develop_branch" || error_exit "Failed to switch to $develop_branch"
    
    ### Merge feature branch ###
    if git merge "$branch_name" --no-ff -m "Merge feature: $feature_name"; then
        print_success "Feature $feature_name merged into $develop_branch"
        
        ### Delete feature branch ###
        if ask_yes_no "Delete feature branch $branch_name?" "yes"; then
            git branch -d "$branch_name"
            print_success "Deleted feature branch: $branch_name"
        fi
        
        return 0
    else
        error_exit "Failed to merge feature branch"
    fi
}


################################################################################
### === RELEASE MANAGEMENT === ###
################################################################################

### Create version tag ###
create_version_tag() {
    local version="$1"
    local message="$2"
    
    if [ -z "$version" ]; then
        print_error "Usage: create_version_tag <version> [message]"
        print_info "Example: create_version_tag v1.2.3 'Release with new features'"
        return 1
    fi
    
    ### Add version prefix if needed ###
    local version_prefix="${VERSION_PREFIX:-v}"
    if [[ ! "$version" =~ ^$version_prefix[0-9] ]]; then
        version="${version_prefix}$version"
    fi
    
    ### Validate version format ###
    if [[ ! "$version" =~ ^$version_prefix[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format. Use ${version_prefix}X.Y.Z (e.g., ${version_prefix}1.2.3)"
        return 1
    fi
    
    ### Check if tag exists ###
    if git tag -l | grep -q "^$version$"; then
        print_error "Tag $version already exists"
        return 1
    fi
    
    ### Create annotated tag ###
    local tag_message="${message:-Release $version}"
    
    if git tag -a "$version" -m "$tag_message"; then
        print_success "Created tag: $version"
        print_info "Message: $tag_message"
        return 0
    else
        error_exit "Failed to create tag"
    fi
}

### Create full release ###
create_release() {
    local version="$1"
    local message="$2"
    
    if [ -z "$version" ]; then
        print_error "Usage: create_release <version> [message]"
        print_info "Example: create_release 1.2.3 'Major feature release'"
        return 1
    fi
    
    local main_branch="${REPO_BRANCH:-main}"
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    
    print_header "Creating Release: $version"
    
    ### Ensure branches exist ###
    if ! git show-ref --verify --quiet "refs/heads/$develop_branch"; then
        error_exit "$develop_branch branch not found"
    fi
    
    if ! git show-ref --verify --quiet "refs/heads/$main_branch"; then
        git checkout -b "$main_branch"
        print_info "Created $main_branch branch"
    fi
    
    ### Switch to develop and ensure it's clean ###
    git checkout "$develop_branch"
    
    if ! git diff --quiet; then
        print_warning "Uncommitted changes in $develop_branch"
        if ! ask_yes_no "Continue with release anyway?" "no"; then
            print_info "Release cancelled"
            return 1
        fi
    fi
    
    ### Merge develop to main ###
    git checkout "$main_branch"
    
    if git merge "$develop_branch" --no-ff -m "Release $version"; then
        print_success "Merged $develop_branch to $main_branch"
    else
        error_exit "Failed to merge for release"
    fi
    
    ### Create version tag ###
    create_version_tag "$version" "$message"
    
    ### Switch back to develop ###
    git checkout "$develop_branch"
    
    print_success "Release $version created successfully!"
    
    ### Ask to push ###
    if ask_yes_no "Push release to remote repository?" "yes"; then
        push_to_remote true
    fi
}


################################################################################
### === REMOTE SYNCHRONIZATION === ###
################################################################################

### Push changes to remote ###
push_to_remote() {
    local push_tags="${1:-false}"
    local branch=$(git branch --show-current)
    
    print_header "Pushing to Remote Repository"
    
    ### Check if remote exists ###
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_warning "No remote repository configured"
        return 1
    fi
    
    ### Push current branch ###
    print_info "Pushing $branch branch..."
    
    if git push origin "$branch" 2>/dev/null; then
        print_success "Pushed $branch branch"
    else
        print_warning "Failed to push $branch branch"
        return 1
    fi
    
    ### Push tags if requested ###
    if [ "$push_tags" = "true" ] || [ "$push_tags" = "yes" ]; then
        print_info "Pushing tags..."
        
        if git push origin --tags 2>/dev/null; then
            print_success "Pushed tags"
        else
            print_warning "Failed to push tags"
        fi
    fi
    
    return 0
}

### Pull changes from remote ###
pull_from_remote() {
    local branch="${1:-$(git branch --show-current)}"
    
    print_header "Pulling from Remote Repository"
    
    ### Check if remote exists ###
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_warning "No remote repository configured"
        return 1
    fi
    
    ### Fetch latest changes ###
    print_info "Fetching latest changes..."
    
    if git fetch origin 2>/dev/null; then
        print_success "Fetched latest changes"
    else
        print_warning "Failed to fetch changes"
        return 1
    fi
    
    ### Pull changes ###
    print_info "Pulling $branch branch..."
    
    if git pull origin "$branch" 2>/dev/null; then
        print_success "Pulled latest changes for $branch"
        return 0
    else
        print_warning "Failed to pull changes"
        return 1
    fi
}

### Full synchronization ###
sync_with_remote() {
    local push_after_pull="${1:-true}"
    
    print_header "Synchronizing with Remote Repository"
    
    ### Pull latest changes ###
    if pull_from_remote; then
        print_info "Pull completed successfully"
    else
        print_warning "Pull failed, continuing..."
    fi
    
    ### Push local changes if requested ###
    if [ "$push_after_pull" = "true" ]; then
        echo ""
        if push_to_remote; then
            print_info "Push completed successfully"
        else
            print_warning "Push failed"
        fi
    fi
    
    print_success "Synchronization completed"
}


################################################################################
### === STATUS AND INFORMATION === ###
################################################################################

### Show File Version Status ###
show_file_status() {
    local file="$1"
    
    validate_file "$file" true
    
    print_header "File Status: $(basename "$file")"
    
    ### Version information using helper function ###
    local version=$(header --get-version "$file")
    local commit_msg=""
    
    if grep -q "^COMMIT=" "$file"; then
        commit_msg=$(grep "^COMMIT=" "$file" | cut -d'"' -f2)
    fi
    
    print_info "Version Information:"
    echo "  Current Version: $version"
    echo "  Commit Message:  ${commit_msg:-Not set}"
    echo "  Last Modified:   $(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")"
    echo ""
    
    ### Git information if available ###
    if git rev-parse --git-dir >/dev/null 2>&1; then
        print_info "Git Information:"
        
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            echo "  Git Status:      $(git status --porcelain "$file" | cut -c1-2 || echo "Clean")"
            echo "  Last Commit:     $(git log -1 --format='%h - %s' -- "$file" 2>/dev/null || echo 'Never committed')"
            echo "  Last Author:     $(git log -1 --format='%an' -- "$file" 2>/dev/null || echo 'Unknown')"
            echo "  Total Commits:   $(git rev-list --count HEAD -- "$file" 2>/dev/null || echo '0')"
        else
            echo "  Git Status:      Not tracked"
        fi
    fi
}

### List all Project Files with Versions ###
list_project_files() {
    print_header "Project Files with Versions"
    
    ### Find files with SCRIPT_VERSION ###
    local files=($(find "${PROJECT_ROOT:-$PWD}" -name "*.sh" -exec grep -l "SCRIPT_VERSION=" {} \; 2>/dev/null))
    
    if [ ${#files[@]} -eq 0 ]; then
        print_warning "No versioned files found"
        return 1
    fi
    
    print_info "Found ${#files[@]} versioned files:"
    echo ""
    
    ### Display files with versions using helper function ###
    for file in "${files[@]}"; do
        local version=$(header --get-version "$file")
        local relative_path="${file#$PWD/}"
        printf "  %-30s v%s\n" "$(basename "$file")" "$version"
    done
    
    echo ""
    print_info "Use 'show_file_status <file>' for detailed information"
}

### Repository health check ###
check_repository_health() {
    print_header "Git Repository Health Check"
    
    local issues=0
    
    ### Check if in git repository ###
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi
    print_check "Git repository detected"
    
    ### Check remote configuration ###
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_cross "No remote 'origin' configured"
        ((issues++))
    else
        local remote_url=$(git remote get-url origin)
        print_check "Remote origin: $remote_url"
    fi
    
    ### Check git user configuration ###
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
    
    ### Check if ahead/behind remote ###
    if git remote get-url origin >/dev/null 2>&1; then
        local current_branch=$(git branch --show-current)
        git fetch origin 2>/dev/null || true
        
        local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        
        if [ "$ahead" -gt 0 ]; then
            print_warning "Local branch is $ahead commits ahead of remote"
        fi
        
        if [ "$behind" -gt 0 ]; then
            print_warning "Local branch is $behind commits behind remote"
        fi
        
        if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
            print_check "Branch synchronized with remote"
        fi
    fi
    
    ### Check branch structure ###
    local main_branch="${REPO_BRANCH:-main}"
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    
    if git show-ref --verify --quiet "refs/heads/$main_branch"; then
        print_check "$main_branch branch exists"
    else
        print_cross "$main_branch branch missing"
        ((issues++))
    fi
    
    if git show-ref --verify --quiet "refs/heads/$develop_branch"; then
        print_check "$develop_branch branch exists"
    else
        print_cross "$develop_branch branch missing"
        ((issues++))
    fi
    
    ### Summary ###
    echo ""
    if [ $issues -eq 0 ]; then
        print_success "Repository health: EXCELLENT ✨"
        print_info "All checks passed successfully"
    elif [ $issues -le 2 ]; then
        print_warning "Repository health: GOOD ($issues minor issues)"
        print_info "Consider addressing the issues above"
    else
        print_error "Repository health: NEEDS ATTENTION ($issues issues)"
        print_info "Please fix the issues before continuing"
    fi
    
    return $issues
}

### Show comprehensive git repository status ###
show_git_status() {
    print_header "Git Repository Status"
    
    ### Check if in repository ###
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi
    
    ### Basic repository information ###
    print_section "Repository Information"
    echo "  Repository Root: $(git rev-parse --show-toplevel)"
    echo "  Current Branch:  $(git branch --show-current)"
    echo "  Remote URL:      $(git remote get-url origin 2>/dev/null || echo 'No remote configured')"
    echo "  Total Branches:  $(git branch -a | wc -l)"
    echo "  Total Tags:      $(git tag | wc -l)"
    echo ""
    
    ### Recent commits ###
    print_section "Recent Commits"
    git log --oneline -5 2>/dev/null || echo "  No commits found"
    echo ""
    
    ### Working tree status ###
    print_section "Working Tree Status"
    local status_output=$(git status --porcelain)
    
    if [ -z "$status_output" ]; then
        print_success "Working tree is clean"
    else
        local modified=$(echo "$status_output" | grep -c "^ M" || echo "0")
        local untracked=$(echo "$status_output" | grep -c "^??" || echo "0") 
        local staged=$(echo "$status_output" | grep -c "^[AM]" || echo "0")
        
        echo "  Modified files:  $modified"
        echo "  Untracked files: $untracked"
        echo "  Staged files:    $staged"
        
        if [ $modified -gt 0 ]; then
            echo ""
            print_info "Modified files:"
            git status --porcelain | grep "^ M" | sed 's/^ M /  • /'
        fi
        
        if [ $untracked -gt 0 ]; then
            echo ""
            print_info "Untracked files:"
            git status --porcelain | grep "^??" | sed 's/^?? /  • /'
        fi
    fi
    echo ""
    
    ### Remote synchronization status ###
    if git remote get-url origin >/dev/null 2>&1; then
        print_section "Remote Synchronization"
        git fetch --dry-run 2>&1 | grep -q "up to date" && print_check "Remote is up to date" || print_warning "Remote updates available"
        
        local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        
        echo "  Commits ahead:   $ahead"
        echo "  Commits behind:  $behind"
    fi
}


################################################################################
### === UNIFIED MENU SYSTEM === ###
################################################################################

### Unified Menu Function with parameter-based Navigation ###
show_menu() {
    local menu_type="${1:-main}"
    shift
    
    case "$menu_type" in
        --main|main)
            _show_main_menu
            ;;
        --update-header)
            _show_update_header_menu
            ;;
        --commit-update)
            _show_commit_update_menu
            ;;
        --batch-update)
            _show_batch_update_menu
            ;;
        --file-status)
            _show_file_status_menu "$@"
            ;;
        --init-repo)
            _show_init_repo_menu
            ;;
        --clone-repo)
            _show_clone_repo_menu
            ;;
        --create-feature)
            _show_create_feature_menu
            ;;
        --finish-feature)
            _show_finish_feature_menu
            ;;
        --create-tag)
            _show_create_tag_menu
            ;;
        --create-release)
            _show_create_release_menu
            ;;
        --help|-h)
            show_help_documentation
            show_menu --main
            ;;
        *)
            print_error "Unknown menu type: $menu_type"
            print_info "Usage: show_menu [--main|--update-header|--commit-update|--batch-update|"
            print_info "                  --file-status|--init-repo|--clone-repo|--create-feature|"
            print_info "                  --finish-feature|--create-tag|--create-release|--help]"
            return 1
            ;;
    esac

    ################################################################################
    ### === INTERNAL MENU FUNCTIONS === ###
    ################################################################################

    ### Main interactive menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_main_menu() {
        clear
        print_header "Git Workflow Manager - Interactive Menu"
        
        echo "📋 AVAILABLE ACTIONS:"
        echo ""
        echo "  === FILE & VERSION MANAGEMENT ==="
        echo "   1) Update file header with version bump"
        echo "   2) Commit file with header update"
        echo "   3) Batch update multiple files"
        echo "   4) Show file version status"
        echo "   5) List all project files"
        echo ""
        echo "  === REPOSITORY MANAGEMENT ==="
        echo "   6) Initialize git repository"
        echo "   7) Clone remote repository"
        echo "   8) Show git repository status"
        echo "   9) Repository health check"
        echo ""
        echo "  === BRANCH MANAGEMENT ==="
        echo "  10) Setup branch structure (main/develop)"
        echo "  11) Create feature branch"
        echo "  12) Finish feature branch"
        echo ""
        echo "  === RELEASE MANAGEMENT ==="
        echo "  13) Create version tag"
        echo "  14) Create full release"
        echo ""
        echo "  === SYNCHRONIZATION ==="
        echo "  15) Push to remote repository"
        echo "  16) Pull from remote repository"
        echo "  17) Full sync with remote"
        echo ""
        echo "  === HELP & EXIT ==="
        echo "  18) Show detailed help"
        echo "  19) Exit"
        echo ""
        
        read -p "Enter your choice [1-19]: " choice
        
        case $choice in
            1) show_menu --update-header ;;
            2) show_menu --commit-update ;;
            3) show_menu --batch-update ;;
            4) show_menu --file-status ;;
            5) list_project_files; pause; show_menu --main ;;
            6) show_menu --init-repo ;;
            7) show_menu --clone-repo ;;
            8) show_git_status; pause; show_menu --main ;;
            9) check_repository_health; pause; show_menu --main ;;
            10) setup_branch_structure; pause; show_menu --main ;;
            11) show_menu --create-feature ;;
            12) show_menu --finish-feature ;;
            13) show_menu --create-tag ;;
            14) show_menu --create-release ;;
            15) push_to_remote; pause; show_menu --main ;;
            16) pull_from_remote; pause; show_menu --main ;;
            17) sync_with_remote; pause; show_menu --main ;;
            18) show_help_documentation; show_menu --main ;;
            19) print_info "Exiting Git Workflow Manager..."; exit 0 ;;
            *)
                print_error "Invalid choice. Please select 1-19."
                pause
                show_menu --main
                ;;
        esac
    }

    ### Update header menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_update_header_menu() {
        clear
        print_header "Update File Header"
        
        local file=$(ask_input "Enter file path")
        local commit_msg=$(ask_input "Enter commit message" "Auto update")
        local version_type=$(ask_input "Version increment type (major/minor/patch)" "patch")
        
        if validate_file "$file" false; then
            header --update "$file" "$commit_msg" "$version_type"
        else
            print_error "File not found: $file"
        fi
        
        pause
        show_menu --main
    }

    ### Commit with update menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_commit_update_menu() {
        clear
        print_header "Commit with Header Update"
        
        local file=$(ask_input "Enter file path")
        local commit_msg=$(ask_input "Enter commit message")
        local version_type=$(ask_input "Version increment type (major/minor/patch)" "patch")
        
        if [ -n "$file" ] && [ -n "$commit_msg" ]; then
            commit_with_update "$file" "$commit_msg" "$version_type"
        else
            print_error "File path and commit message are required"
        fi
        
        pause
        show_menu --main
    }

    ### Batch update menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_batch_update_menu() {
        clear
        print_header "Batch Update Files"
        
        local commit_msg=$(ask_input "Enter commit message")
        local version_type=$(ask_input "Version increment type (major/minor/patch)" "patch")
        local files_input=$(ask_input "Enter file paths (space-separated)")
        
        if [ -n "$commit_msg" ] && [ -n "$files_input" ]; then
            local files=($files_input)
            batch_commit "$commit_msg" "$version_type" "${files[@]}"
        else
            print_error "Commit message and file paths are required"
        fi
        
        pause
        show_menu --main
    }

    ### File status menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_file_status_menu() {
        clear
        print_header "Show File Status"
        
        local file="${1:-$(ask_input "Enter file path")}"
        
        if [ -n "$file" ]; then
            show_file_status "$file"
        else
            print_error "File path is required"
        fi
        
        pause
        show_menu --main
    }

    ### Initialize repository menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_init_repo_menu() {
        clear
        print_header "Initialize Git Repository"
        
        local repo_dir=$(ask_input "Enter repository directory" "$PROJECT_ROOT")
        
        if [ -n "$repo_dir" ]; then
            init_git_repo "$repo_dir"
        fi
        
        pause
        show_menu --main
    }

    ### Clone repository menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_clone_repo_menu() {
        clear
        print_header "Clone Remote Repository"
        
        ### Check if directory already exists ###
        if [ -d "$PROJECT_ROOT" ]; then
            local dir_status=$(check_target_directory "$PROJECT_ROOT")
            print_info "Current directory status: $dir_status"
            echo ""
        fi
        
        local repo_url=$(ask_input "Enter repository URL" "$REPO_URL")
        local target_dir=$(ask_input "Enter target directory" "$PROJECT_ROOT")
        local branch=$(ask_input "Enter branch name" "$REPO_BRANCH")
        
        if [ -n "$repo_url" ] && [ -n "$target_dir" ]; then
            clone_repository "$repo_url" "$target_dir" "$branch"
            
            ### Show summary after successful clone ###
            if [ $? -eq 0 ]; then
                echo ""
                show_installation_summary "$target_dir"
            fi
        else
            print_error "Repository URL and target directory are required"
        fi
        
        pause
        show_menu --main
    }

    ### Create feature branch menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_create_feature_menu() {
        clear
        print_header "Create Feature Branch"
        
        local feature_name=$(ask_input "Enter feature name (e.g., user-authentication)")
        
        if [ -n "$feature_name" ]; then
            create_feature_branch "$feature_name"
        else
            print_error "Feature name is required"
        fi
        
        pause
        show_menu --main
    }

    ### Finish feature branch menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_finish_feature_menu() {
        clear
        print_header "Finish Feature Branch"
        
        ### Show current feature branches ###
        local feature_branches=($(git branch 2>/dev/null | grep "${FEATURE_BRANCH_PREFIX:-feature/}" | sed 's/^[* ] //' | sed "s/${FEATURE_BRANCH_PREFIX:-feature\/}//"))
        
        if [ ${#feature_branches[@]} -eq 0 ]; then
            print_warning "No feature branches found"
            pause
            show_menu --main
            return
        fi
        
        print_info "Available feature branches:"
        for branch in "${feature_branches[@]}"; do
            echo "  • $branch"
        done
        echo ""
        
        local feature_name=$(ask_input "Enter feature name to finish")
        
        if [ -n "$feature_name" ]; then
            finish_feature_branch "$feature_name"
        else
            print_error "Feature name is required"
        fi
        
        pause
        show_menu --main
    }

    ### Create tag menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_create_tag_menu() {
        clear
        print_header "Create Version Tag"
        
        ### Suggest next version based on latest tag ###
        local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")
        local suggested_version=$(header --increment-version "$latest_tag" "patch")
        
        print_info "Latest tag: ${latest_tag}"
        print_info "Suggested version: ${suggested_version}"
        echo ""
        
        local version=$(ask_input "Enter version number" "$suggested_version")
        local message=$(ask_input "Enter tag message (optional)")
        
        if [ -n "$version" ]; then
            create_version_tag "$version" "$message"
        else
            print_error "Version number is required"
        fi
        
        pause
        show_menu --main
    }

    ### Create release menu (internal) ###
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _show_create_release_menu() {
        clear
        print_header "Create Release"
        
        ### Suggest next version ###
        local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")
        local suggested_version=$(header --increment-version "$latest_tag" "minor")
        
        print_info "Latest tag: ${latest_tag}"
        print_info "Suggested version: ${suggested_version}"
        echo ""
        
        local version=$(ask_input "Enter version number" "$suggested_version")
        local message=$(ask_input "Enter release message (optional)")
        
        if [ -n "$version" ]; then
            create_release "$version" "$message"
        else
            print_error "Version number is required"
        fi
        
        pause
        show_menu --main
    }
}


################################################################################
### === HELP DOCUMENTATION === ###
################################################################################

### Show comprehensive help ###
show_help_documentation() {
    clear
    print_header "Git Workflow Manager - Complete Documentation"
    
    echo "🔧 DESCRIPTION:"
    echo "    Complete Git repository management system with automated version"
    echo "    control, branch management, and release workflows."
    echo ""
    echo "📌 USAGE:"
    echo "    ./git.sh [OPTIONS]                       # Run with options"
    echo "    ./git.sh                                 # Interactive menu"
    echo "    source git.sh                           # Load functions"
    echo ""
    echo "🎯 KEY FEATURES:"
    echo "    • Automatic file header version management"
    echo "    • Git workflow automation (feature branches, releases)"
    echo "    • Repository initialization and cloning"
    echo "    • Remote synchronization"
    echo "    • Branch structure setup (main/develop)"
    echo "    • Version tagging and release management"
    echo "    • Repository health monitoring"
    echo "    • Batch file operations"
    echo ""
    echo "📚 MAIN FUNCTIONS:"
    echo ""
    echo "  FILE & VERSION MANAGEMENT:"
    echo "    update_file_header <file> [msg] [type]   - Update file header"
    echo "    commit_with_update <file> <msg> [type]   - Update and commit"
    echo "    batch_commit <msg> [type] <files...>     - Batch update/commit"
    echo "    get_file_version <file>                  - Get file version"
    echo "    increment_version <version> [type]       - Increment version"
    echo ""
    echo "  REPOSITORY MANAGEMENT:"
    echo "    init_git_repo [directory]                - Initialize repository"
    echo "    clone_repository <url> [dir] [branch]    - Clone repository"
    echo "    check_repository_health                  - Health check"
    echo "    show_git_status                          - Detailed status"
    echo ""
    echo "  BRANCH MANAGEMENT:"
    echo "    setup_branch_structure                   - Setup main/develop"
    echo "    create_feature_branch <name>             - Create feature branch"
    echo "    finish_feature_branch <name>             - Merge feature branch"
    echo ""
    echo "  RELEASE MANAGEMENT:"
    echo "    create_version_tag <version> [message]   - Create version tag"
    echo "    create_release <version> [message]       - Full release process"
    echo ""
    echo "  SYNCHRONIZATION:"
    echo "    push_to_remote [push_tags]               - Push to remote"
    echo "    pull_from_remote [branch]                - Pull from remote"
    echo "    sync_with_remote [push_after]            - Full synchronization"
    echo ""
    echo "  STATUS & INFORMATION:"
    echo "    show_file_status <file>                  - File version status"
    echo "    list_project_files                       - List versioned files"
    echo ""
    echo "📋 COMMAND LINE OPTIONS:"
    echo "    -h, --help                               - Show help"
    echo "    -i, --init [directory]                   - Initialize repository"
    echo "    -c, --clone <url> [directory] [branch]   - Clone repository" 
    echo "    -s, --status [file]                      - Show status"
    echo "    -u, --update <file> <msg> [type]         - Update file header"
    echo "    -b, --batch <msg> [type] <files...>      - Batch update"
    echo "    -f, --feature <name>                     - Create feature branch"
    echo "    -r, --release <version> [message]        - Create release"
    echo "    -t, --tag <version> [message]            - Create tag"
    echo "    --push [tags]                            - Push to remote"
    echo "    --pull [branch]                          - Pull from remote"
    echo "    --sync                                   - Synchronize"
    echo "    --health                                 - Health check"
    echo "    --interactive                            - Interactive menu"
    echo "    -v, --version                            - Show version"
    echo ""
    echo "🔄 VERSION INCREMENT TYPES:"
    echo "    major     - X.0.0 (breaking changes)"
    echo "    minor     - X.Y.0 (new features)"
    echo "    patch     - X.Y.Z (bug fixes) [default]"
    echo ""
    echo "🌿 BRANCH WORKFLOW:"
    echo "    1. setup_branch_structure                - Create main/develop"
    echo "    2. create_feature_branch <name>          - Start new feature"
    echo "    3. [work on feature]                     - Make changes"
    echo "    4. commit_with_update <file> <msg>       - Update and commit"
    echo "    5. finish_feature_branch <name>          - Merge to develop"
    echo "    6. create_release <version>              - Create release"
    echo ""
    echo "🚀 EXAMPLES:"
    echo "    $0 --init /opt/myproject                 # Initialize repository"
    echo "    $0 --clone https://github.com/user/repo  # Clone repository"
    echo "    $0 --update script.sh 'Fix bug' patch   # Update file header"
    echo "    $0 --feature user-auth                   # Create feature branch"
    echo "    $0 --release 1.2.0 'New features'       # Create release"
    echo "    $0 --batch 'Update all' patch *.sh      # Batch update files"
    echo "    $0 --health                              # Check repo health"
    echo "    $0 --sync                                # Sync with remote"
    echo "    $0 --check-updates                       # Check for updates"
    echo "    $0 --validate                            # Validate installation"
    echo "    $0 --summary                             # Show installation summary"
    echo ""
    echo "💡 INTEGRATION:"
    echo "    • Integrates with project.conf configuration"
    echo "    • Uses helper.sh for utility functions"
    echo "    • Supports custom branch prefixes and naming"
    echo "    • Automatic version detection and increment"
    echo "    • Remote repository synchronization"
    echo ""
    echo "⚙️ CONFIGURATION VARIABLES (project.conf):"
    echo "    REPO_URL                 - Remote repository URL"
    echo "    REPO_BRANCH              - Main branch name (default: main)"
    echo "    REPO_DEVELOP_BRANCH      - Develop branch name (default: develop)"
    echo "    FEATURE_BRANCH_PREFIX    - Feature branch prefix (default: feature/)"
    echo "    VERSION_PREFIX           - Version tag prefix (default: v)"
    echo "    GIT_USER_NAME            - Git user name"
    echo "    GIT_USER_EMAIL           - Git user email"
    echo ""
    
    pause "Press Enter to continue..."
}

### Show quick help ###
show_quick_help() {
    echo "Git Workflow Manager v${SCRIPT_VERSION}"
    echo "Usage: $0 [OPTIONS]"
    echo "Try '$0 --help' for complete documentation."
    echo "Try '$0 --interactive' for interactive menu."
}

### Show version information ###
show_version_info() {
    echo "Git Workflow Manager v${SCRIPT_VERSION}"
    echo "Complete Git repository management system"
    echo "Copyright (c) 2025 Mawage (Workflow Team)"
    echo "License: MIT"
}


################################################################################
### === MAIN EXECUTION === ###
################################################################################

### Parse command line arguments ###
parse_arguments() {
    ### Store original arguments for logging ###
    local ORIGINAL_ARGS=("$@")
    
    ### Parse arguments ###
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help_documentation
                exit 0
                ;;
            -V|--version)
                show_version_info
                exit 0
                ;;
            --interactive)
                show_workflow_menu
                exit 0
                ;;
            -i|--init)
                shift
                local directory="${1:-$PROJECT_ROOT}"
                init_git_repo "$directory"
                exit 0
                ;;
            -c|--clone)
                shift
                if [ -z "$1" ]; then
                    print_error "Repository URL is required for clone"
                    show_quick_help
                    exit 1
                fi
                local url="$1"
                local directory="${2:-$PROJECT_ROOT}"
                local branch="${3:-$REPO_BRANCH}"
                shift
                [ -n "$1" ] && ! [[ "$1" == -* ]] && { directory="$1"; shift; }
                [ -n "$1" ] && ! [[ "$1" == -* ]] && { branch="$1"; shift; }
                
                clone_repository "$url" "$directory" "$branch"
                
                ### Validate and show summary ###
                if validate_installation "$directory"; then
                    show_installation_summary "$directory"
                fi
                exit 0
                ;;
            --check-updates)
                shift
                local repo_dir="${1:-$PROJECT_ROOT}"
                check_git_version "$repo_dir"
                exit 0
                ;;
            --validate)
                shift
                local repo_dir="${1:-$PROJECT_ROOT}"
                validate_installation "$repo_dir"
                exit 0
                ;;
            --summary)
                shift
                local repo_dir="${1:-$PROJECT_ROOT}"
                show_installation_summary "$repo_dir"
                exit 0
                ;;
            --set-permissions)
                shift
                local repo_dir="${1:-$PROJECT_ROOT}"
                if is_root; then
                    set_repository_permissions "$repo_dir"
                else
                    print_error "Root privileges required for setting permissions"
                    exit 1
                fi
                exit 0
                ;;
            -s|--status)
                shift
                if [ -n "$1" ] && [ ! "$1" = -* ]; then
                    show_file_status "$1"
                else
                    show_git_status
                fi
                exit 0
                ;;
            -u|--update)
                shift
                if [ -z "$1" ] || [ -z "$2" ]; then
                    print_error "Usage: $0 --update <file> <commit_message> [version_type]"
                    exit 1
                fi
                local file="$1"
                local message="$2"
                local type="${3:-patch}"
                commit_with_update "$file" "$message" "$type"
                exit 0
                ;;
            -b|--batch)
                shift
                if [ -z "$1" ]; then
                    print_error "Usage: $0 --batch <commit_message> [version_type] <files...>"
                    exit 1
                fi
                local message="$1"
                local type="patch"
                shift
                
                ### Check if next arg is version type ###
                if [[ "$1" =~ ^(major|minor|patch)$ ]]; then
                    type="$1"
                    shift
                fi
                
                if [ $# -eq 0 ]; then
                    print_error "No files specified for batch update"
                    exit 1
                fi
                
                batch_commit "$message" "$type" "$@"
                exit 0
                ;;
            -f|--feature)
                shift
                if [ -z "$1" ]; then
                    print_error "Feature name is required"
                    exit 1
                fi
                create_feature_branch "$1"
                exit 0
                ;;
            --finish-feature)
                shift
                if [ -z "$1" ]; then
                    print_error "Feature name is required"
                    exit 1
                fi
                finish_feature_branch "$1"
                exit 0
                ;;
            -r|--release)
                shift
                if [ -z "$1" ]; then
                    print_error "Version is required for release"
                    exit 1
                fi
                create_release "$1" "$2"
                exit 0
                ;;
            -t|--tag)
                shift
                if [ -z "$1" ]; then
                    print_error "Version is required for tag"
                    exit 1
                fi
                create_version_tag "$1" "$2"
                exit 0
                ;;
            --push)
                shift
                local push_tags="${1:-false}"
                push_to_remote "$push_tags"
                exit 0
                ;;
            --pull)
                shift
                local branch="${1:-$(git branch --show-current 2>/dev/null)}"
                pull_from_remote "$branch"
                exit 0
                ;;
            --sync)
                sync_with_remote
                exit 0
                ;;
            --health)
                check_repository_health
                exit 0
                ;;
            --setup-branches)
                setup_branch_structure
                exit 0
                ;;
            --list-files)
                list_project_files
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_quick_help
                exit 1
                ;;
            *)
                print_error "Unexpected argument: $1"
                show_quick_help
                exit 1
                ;;
        esac
        shift
    done
}

### Main function ###
main() {
    ### Load configuration and dependencies ###
    load_config
    
    ### Initialize logging ###
    init_logging "${LOG_DIR}/git-workflow.log" "${LOG_LEVEL_INFO}"
    
    ### Log startup ###
    log_info "Git Workflow Manager started with args: $*"
    
    ### Check if no arguments provided ###
    if [ $# -eq 0 ]; then
        print_header "Git Workflow Manager v${SCRIPT_VERSION}"
        echo ""
        echo "📋 QUICK ACTIONS:"
        echo "  $0 --interactive         # Interactive menu"
        echo "  $0 --help               # Complete documentation"
        echo "  $0 --status             # Repository status"
        echo "  $0 --health             # Health check"
        echo ""
        echo "🔧 COMMON OPERATIONS:"
        echo "  $0 --update <file> <msg>          # Update file version"
        echo "  $0 --feature <name>               # Create feature branch"
        echo "  $0 --release <version>            # Create release"
        echo "  $0 --sync                         # Sync with remote"
        echo ""
        print_info "Use --interactive for guided menu or --help for complete options"
        exit 0
    else
        ### Parse and execute arguments ###
        parse_arguments "$@"
    fi
}

### Cleanup function ###
cleanup() {
    log_info "Git Workflow Manager cleanup"
}

### Initialize when run directly ###
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    ### Running directly ###
    main "$@"
else
    ### Being sourced ###
    load_config
    print_success "Git Workflow Manager loaded. Type 'show_workflow_menu' for interactive menu."
fi