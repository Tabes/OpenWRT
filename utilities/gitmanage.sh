#!/bin/bash
################################################################################
### Git Management System - Repository Operations
### Handles all Git-related operations for project management
################################################################################
### Project: Universal Git Manager
### Version: 1.0.0
### Author:  Mawage (Git Management Team)
### Date:    2025-08-20
### License: MIT
### Usage:   Source this file and use git management functions
################################################################################

SCRIPT_VERSION="1.0.0"
COMMIT="Git management system for repository operations"

### Colors ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

### Print Functions ###
print_success() { echo -e "${GREEN}✅ $*${NC}"; }
print_error() { echo -e "${RED}❌ $*${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $*${NC}"; }
print_info() { echo -e "${BLUE}ℹ️ $*${NC}"; }

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

### Load project configuration ###
load_config() {
    if [ -f "project.conf" ]; then
        source project.conf
    fi
}

### Setup branch structure ###
setup_branches() {
    print_info "Setting up branch structure..."
    load_config
    
    local main_branch="${REPO_BRANCH:-main}"
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    
    # Ensure main branch exists
    git checkout "$main_branch" 2>/dev/null || git checkout -b "$main_branch"
    
    # Create develop branch if needed
    if ! git show-ref --verify --quiet "refs/heads/$develop_branch"; then
        git checkout -b "$develop_branch"
        print_success "Created $develop_branch branch"
    else
        print_info "$develop_branch branch already exists"
    fi
    
    # Set upstream tracking
    git branch --set-upstream-to="origin/$main_branch" "$main_branch" 2>/dev/null || true
    git branch --set-upstream-to="origin/$develop_branch" "$develop_branch" 2>/dev/null || true
    
    git checkout "$develop_branch"
    print_success "Branch structure ready"
}

### Create version tag ###
create_tag() {
    local version="$1"
    local message="$2"
    load_config
    
    if [ -z "$version" ]; then
        echo "Usage: create_tag <version> [message]"
        echo "Example: create_tag v1.2.3 'Release with new features'"
        return 1
    fi
    
    # Add version prefix if needed
    if [[ ! "$version" =~ ^v[0-9] ]]; then
        version="${VERSION_PREFIX:-v}$version"
    fi
    
    # Validate version format
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format. Use vX.Y.Z (e.g., v1.2.3)"
        return 1
    fi
    
    # Check if tag exists
    if git tag -l | grep -q "^$version$"; then
        print_error "Tag $version already exists"
        return 1
    fi
    
    # Create annotated tag
    local tag_message="${message:-Release $version}"
    git tag -a "$version" -m "$tag_message"
    
    print_success "Created tag: $version"
    print_info "Message: $tag_message"
    
    return 0
}

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

### Start feature branch ###
start_feature() {
    local feature_name="$1"
    load_config
    
    if [ -z "$feature_name" ]; then
        echo "Usage: start_feature <feature_name>"
        echo "Example: start_feature enhanced-validation"
        return 1
    fi
    
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    local feature_prefix="${FEATURE_BRANCH_PREFIX:-feature/}"
    local branch_name="${feature_prefix}${feature_name}"
    
    # Switch to develop and update
    git checkout "$develop_branch"
    git pull origin "$develop_branch" 2>/dev/null || true
    
    # Create feature branch
    git checkout -b "$branch_name"
    
    print_success "Created feature branch: $branch_name"
    print_info "Work on your feature, then run: finish_feature $feature_name"
}

### Finish feature branch ###
finish_feature() {
    local feature_name="$1"
    load_config
    
    if [ -z "$feature_name" ]; then
        echo "Usage: finish_feature <feature_name>"
        return 1
    fi
    
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    local feature_prefix="${FEATURE_BRANCH_PREFIX:-feature/}"
    local branch_name="${feature_prefix}${feature_name}"
    local current_branch=$(git branch --show-current)
    
    # Ensure we're on the feature branch
    if [ "$current_branch" != "$branch_name" ]; then
        git checkout "$branch_name" || {
            print_error "Feature branch $branch_name not found"
            return 1
        }
    fi
    
    # Merge back to develop
    git checkout "$develop_branch"
    git merge "$branch_name" --no-ff -m "Merge feature: $feature_name"
    
    # Delete feature branch
    git branch -d "$branch_name"
    
    print_success "Feature $feature_name merged and cleaned up"
}

### Create release ###
create_release() {
    local version="$1"
    local message="$2"
    load_config
    
    if [ -z "$version" ]; then
        echo "Usage: create_release <version> [message]"
        echo "Example: create_release v1.2.3 'Major feature release'"
        return 1
    fi
    
    local main_branch="${REPO_BRANCH:-main}"
    local develop_branch="${REPO_DEVELOP_BRANCH:-develop}"
    
    print_info "Creating release $version..."
    
    # Ensure we're on develop
    git checkout "$develop_branch"
    
    # Merge to main
    git checkout "$main_branch"
    git merge "$develop_branch" --no-ff -m "Release $version"
    
    # Create tag
    create_tag "$version" "$message"
    
    # Back to develop
    git checkout "$develop_branch"
    
    print_success "Release $version created!"
    
    # Ask to push
    if ask_yes_no "Push release to remote?" "yes"; then
        push_changes "true"
    fi
}

### Sync with remote ###
sync_remote() {
    local branch=$(git branch --show-current)
    
    print_info "Syncing $branch with remote..."
    
    # Fetch latest changes
    git fetch origin 2>/dev/null || {
        print_warning "Could not fetch from remote"
        return 1
    }
    
    # Pull changes
    if git pull origin "$branch" 2>/dev/null; then
        print_success "Pulled latest changes"
    else
        print_warning "Could not pull changes"
    fi
    
    # Push local changes
    if git push origin "$branch" 2>/dev/null; then
        print_success "Pushed local changes"
    else
        print_warning "Could not push changes"
    fi
}

### Project status ###
project_status() {
    load_config
    local project_name="${PROJECT_NAME:-Unknown Project}"
    
    echo "=== $project_name Status ==="
    echo ""
    
    print_info "Current Branch: $(git branch --show-current)"
    
    # Repository info
    local repo_url=$(git remote get-url origin 2>/dev/null || echo "No remote")
    print_info "Repository: $repo_url"
    
    # Latest tags
    echo ""
    print_info "Latest Tags:"
    git tag --sort=-version:refname | head -5 2>/dev/null || echo "  No tags found"
    
    # Recent commits
    echo ""
    print_info "Recent Commits:"
    git log --oneline -5 2>/dev/null || echo "  No commits found"
    
    # Branch overview
    echo ""
    print_info "Branches:"
    git branch -a 2>/dev/null | head -10 || echo "  No branches found"
    
    # Working directory status
    echo ""
    local status=$(git status --porcelain 2>/dev/null)
    if [ -n "$status" ]; then
        print_warning "Uncommitted changes:"
        echo "$status" | head -5
    else
        print_success "Working directory clean"
    fi
}

### Repository health check ###
repo_health() {
    print_info "Repository Health Check..."
    
    local issues=0
    
    # Check if in git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi
    
    # Check remote
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_warning "No remote 'origin' configured"
        ((issues++))
    fi
    
    # Check user config
    local user_name=$(git config user.name 2>/dev/null)
    local user_email=$(git config user.email 2>/dev/null)
    
    if [ -z "$user_name" ]; then
        print_warning "Git user.name not configured"
        ((issues++))
    fi
    
    if [ -z "$user_email" ]; then
        print_warning "Git user.email not configured"
        ((issues++))
    fi
    
    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null; then
        print_warning "Uncommitted changes in working directory"
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        print_success "Repository health: Good"
    else
        print_warning "Repository health: $issues issues found"
    fi
    
    return $issues
}

### Git manager menu ###
show_git_menu() {
    echo ""
    echo "=== Git Management Commands ==="
    echo ""
    echo "🌿 Branch Management:"
    echo "  setup_branches                      - Setup main/develop structure"
    echo "  start_feature <name>                - Create feature branch"
    echo "  finish_feature <name>               - Merge feature back"
    echo ""
    echo "🏷️ Release Management:"
    echo "  create_tag <version> [message]      - Create version tag"
    echo "  create_release <version> [message]  - Full release process"
    echo ""
    echo "🔄 Synchronization:"
    echo "  push_changes [push_tags]            - Push to remote"
    echo "  sync_remote                         - Sync with remote"
    echo ""
    echo "📊 Information:"
    echo "  project_status                      - Show project overview"
    echo "  repo_health                         - Check repository health"
    echo ""
    echo "Examples:"
    echo "  start_feature my-enhancement"
    echo "  finish_feature my-enhancement"
    echo "  create_release v1.2.0 'New features'"
}

### Initialize ###
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    show_git_menu
    echo ""
    echo "Usage: source git_manager.sh && <command>"
else
    load_config
    print_success "Git manager loaded. Type 'show_git_menu' for help."
fi