#!/bin/bash
################################################################################
### Git Workflow Manager für OpenWRT gitclone.sh Projekt
################################################################################

### Colors ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_msg() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_success() { print_msg "$GREEN" "✅ $*"; }
print_error() { print_msg "$RED" "❌ $*"; }
print_warning() { print_msg "$YELLOW" "⚠️ $*"; }
print_info() { print_msg "$BLUE" "ℹ️ $*"; }

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

### Branch Management ###
setup_branches() {
    print_info "Setting up branch structure..."
    
    # Ensure we have main branch
    git checkout main 2>/dev/null || git checkout -b main
    
    # Create develop branch
    if ! git show-ref --verify --quiet refs/heads/develop; then
        git checkout -b develop
        print_success "Created develop branch"
    else
        print_info "Develop branch already exists"
    fi
    
    git checkout develop
}

### Version Tagging ###
create_version_tag() {
    local version="$1"
    local message="$2"
    
    if [ -z "$version" ]; then
        echo "Usage: create_version_tag <version> [message]"
        echo "Example: create_version_tag v1.2.3 'Added new features'"
        return 1
    fi
    
    # Validate version format
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Version must be in format vX.Y.Z (e.g., v1.2.3)"
        return 1
    fi
    
    # Check if tag exists
    if git tag -l | grep -q "^$version$"; then
        print_error "Tag $version already exists"
        return 1
    fi
    
    # Create tag
    local tag_message="${message:-Release $version}"
    git tag -a "$version" -m "$tag_message"
    
    print_success "Created tag: $version"
    print_info "Message: $tag_message"
    
    # Ask to push
    if ask_yes_no "Push tag to remote?" "yes"; then
        git push origin "$version" 2>/dev/null && print_success "Tag pushed to remote"
    fi
}

### Feature Development ###
start_feature() {
    local feature_name="$1"
    
    if [ -z "$feature_name" ]; then
        echo "Usage: start_feature <feature_name>"
        echo "Example: start_feature enhanced-validation"
        return 1
    fi
    
    git checkout develop
    git pull origin develop 2>/dev/null || true
    
    local branch_name="feature/$feature_name"
    git checkout -b "$branch_name"
    
    print_success "Created feature branch: $branch_name"
    print_info "Work on your feature, then run: finish_feature $feature_name"
}

finish_feature() {
    local feature_name="$1"
    
    if [ -z "$feature_name" ]; then
        echo "Usage: finish_feature <feature_name>"
        return 1
    fi
    
    local branch_name="feature/$feature_name"
    local current_branch=$(git branch --show-current)
    
    if [ "$current_branch" != "$branch_name" ]; then
        git checkout "$branch_name"
    fi
    
    git checkout develop
    git merge "$branch_name" --no-ff -m "Merge feature: $feature_name"
    git branch -d "$branch_name"
    
    print_success "Feature $feature_name merged and cleaned up"
}

### Release Management ###
release_workflow() {
    local version="$1"
    
    if [ -z "$version" ]; then
        echo "Usage: release_workflow <version>"
        echo "Example: release_workflow v1.2.3"
        return 1
    fi
    
    print_info "Starting release workflow for $version..."
    
    # Update version in gitclone.sh
    local version_number=${version#v}
    if [ -f "gitclone.sh" ]; then
        sed -i "s/^SCRIPT_VERSION=.*/SCRIPT_VERSION=\"$version_number\"/" gitclone.sh
        git add gitclone.sh
        git commit -m "Bump version to $version"
        print_success "Version updated in gitclone.sh"
    fi
    
    # Merge to main
    git checkout main
    git merge develop --no-ff -m "Release $version"
    
    # Create tag
    create_version_tag "$version" "Release $version"
    
    # Back to develop
    git checkout develop
    
    print_success "Release $version completed!"
}

### Status Information ###
project_status() {
    echo "=== OpenWRT Project Status ==="
    echo ""
    
    print_info "Current Branch: $(git branch --show-current)"
    
    echo ""
    print_info "Latest Tags:"
    git tag --sort=-version:refname | head -5 || echo "No tags found"
    
    echo ""
    print_info "Recent Commits:"
    git log --oneline -5
    
    echo ""
    print_info "Branch Overview:"
    git branch -a | grep -E "(main|develop|feature|hotfix)" || echo "Only current branch"
    
    echo ""
    if [ -f "gitclone.sh" ]; then
        local current_version=$(grep "^SCRIPT_VERSION=" gitclone.sh | cut -d'"' -f2)
        print_info "Current Script Version: v$current_version"
    fi
}

### Quick Commands ###
quick_commit() {
    local message="$1"
    
    if [ -z "$message" ]; then
        echo "Usage: quick_commit 'commit message'"
        return 1
    fi
    
    git add .
    git commit -m "$message"
    print_success "Changes committed: $message"
}

sync_with_remote() {
    local branch=$(git branch --show-current)
    
    print_info "Syncing $branch with remote..."
    git pull origin "$branch" 2>/dev/null || print_warning "Could not pull from remote"
    git push origin "$branch" 2>/dev/null && print_success "Pushed to remote" || print_warning "Could not push to remote"
}

### Main Menu ###
show_workflow_menu() {
    echo ""
    echo "=== Git Workflow Commands ==="
    echo ""
    echo "🌿 Branch Management:"
    echo "  setup_branches                    - Setup main/develop structure"
    echo "  start_feature <name>              - Create feature branch"
    echo "  finish_feature <name>             - Merge feature back"
    echo ""
    echo "🏷️ Version Management:"
    echo "  create_version_tag <version> [msg] - Create version tag"
    echo "  release_workflow <version>         - Full release process"
    echo ""
    echo "📊 Information:"
    echo "  project_status                     - Show project overview"
    echo ""
    echo "🚀 Quick Actions:"
    echo "  quick_commit 'message'             - Add all and commit"
    echo "  sync_with_remote                   - Pull and push current branch"
    echo ""
    echo "Examples:"
    echo "  start_feature my-enhancement"
    echo "  finish_feature my-enhancement"
    echo "  release_workflow v1.2.0"
}

# Show menu when sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    show_workflow_menu
    echo ""
    echo "Usage: source git-workflow.sh && <command>"
else
    echo "✅ Git workflow commands loaded. Type 'show_workflow_menu' for help."
fi
