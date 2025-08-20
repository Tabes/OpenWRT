#!/bin/bash
################################################################################
### Professional Git Setup Script for gitclone.sh Project
### Automatisches Setup für professionelle Git-Verwaltung
################################################################################
### Version: 1.0.0
### Date:    2025-08-20
### Usage:   Run as root in your OpenWRT repository directory
################################################################################

SETUP_VERSION="1.0.0"
TARGET_DIR="/opt/openWRT"
BACKUP_DIR="/opt/openWRT-backup-$(date +%Y%m%d-%H%M%S)"

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

print_msg() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_header() {
    echo ""
    print_msg "$BLUE" "################################################################################"
    print_msg "$BLUE" "### $1"
    print_msg "$BLUE" "################################################################################"
    echo ""
}

print_step() {
    local step=$1
    shift
    print_msg "$CYAN" "${ARROW} Step $step: $*"
}

print_success() {
    print_msg "$GREEN" "$SUCCESS $*"
}

print_error() {
    print_msg "$RED" "$ERROR $*" >&2
}

print_warning() {
    print_msg "$YELLOW" "$WARNING $*"
}

print_info() {
    print_msg "$WHITE" "$INFO $*"
}

error_exit() {
    print_error "$1"
    exit 1
}

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
### BACKUP AND SAFETY
################################################################################

create_backup() {
    print_info "Creating backup of current installation..."
    
    if [ -d "$TARGET_DIR" ]; then
        if cp -r "$TARGET_DIR" "$BACKUP_DIR" 2>/dev/null; then
            print_success "Backup created: $BACKUP_DIR"
            return 0
        else
            print_error "Failed to create backup"
            return 1
        fi
    else
        print_warning "No existing installation to backup"
        return 0
    fi
}

restore_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        print_warning "Restoring from backup due to error..."
        rm -rf "$TARGET_DIR"
        mv "$BACKUP_DIR" "$TARGET_DIR"
        print_success "Backup restored"
    fi
}

################################################################################
### GIT WORKFLOW SETUP
################################################################################

create_git_workflow_script() {
    print_info "Creating git-workflow.sh management script..."
    
    cat > "$TARGET_DIR/git-workflow.sh" << 'EOF'
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
EOF

    chmod +x "$TARGET_DIR/git-workflow.sh"
    print_success "Created git-workflow.sh"
}

create_project_files() {
    print_info "Creating project documentation files..."
    
    # Create .gitignore
    cat > "$TARGET_DIR/.gitignore" << 'EOF'
# OS specific files
.DS_Store
Thumbs.db
*.swp
*.swo
*~

# Build artifacts
*.log
*.tmp
/tmp/
/logs/
/build/

# IDE files
.vscode/
.idea/
*.code-workspace

# Local configuration overrides
local.cfg
*.local
.env.local

# Test environments
/test-env/
/sandbox/

# Backup directories
*-backup-*/

# Runtime files
*.pid
*.lock
EOF

    # Create README.md
    cat > "$TARGET_DIR/README.md" << 'EOF'
# OpenWRT Builder - Professional Git Repository Manager

Intelligentes Git-Repository-Management mit automatischer Versionserkennung und Self-Update-Funktionen.

## ✨ Features

- ✅ **Automatische Git-Updates** - Erkennt Repository- und Script-Änderungen
- ✅ **Professional Version Checking** - Tag-basiert und Commit-Hash-Vergleich
- ✅ **Self-Updating Script** - Aktualisiert sich automatisch auf neueste Version
- ✅ **Robuste Installation** - Cleanup bei Fehlern, Backup-Funktionen
- ✅ **Git Workflow Management** - Feature-Branches, Releases, Hotfixes
- ✅ **Comprehensive Validation** - Flexible Prüfung mit detaillierten Reports

## 🚀 Installation

```bash
sudo ./gitclone.sh
```

## 📖 Usage

### Basic Commands
```bash
sudo ./gitclone.sh [OPTIONS]

Options:
  -h, --help      Show help message  
  -b, --branch    Specify git branch (default: main)
  -f, --force     Force overwrite without confirmation
  -q, --quiet     Quiet mode (minimal output)
```

### Development Workflow
```bash
# Load workflow commands
source git-workflow.sh

# Start feature development
start_feature my-new-feature

# Work on feature...
quick_commit "Implement new feature"

# Finish feature
finish_feature my-new-feature

# Create release
release_workflow v1.2.0
```

## 🏗️ Git Workflow

### Branch Structure
- **main** - Production releases (tagged versions only)
- **develop** - Development integration
- **feature/\*** - Feature development branches
- **hotfix/\*** - Critical fixes

### Version Management
- **Semantic Versioning**: vMAJOR.MINOR.PATCH (e.g., v1.2.3)
- **Git Tags** für alle Releases
- **Automatic Version Detection** im Script

## 🔧 Development

### Quick Start
```bash
# Setup development environment
source git-workflow.sh
setup_branches

# Check project status
project_status

# Start developing
start_feature enhanced-validation
```

### Release Process
1. Develop in `feature/` branches
2. Merge to `develop`
3. Test thoroughly
4. Run `release_workflow vX.Y.Z`
5. Automatic version update and tagging

## 📊 Status Monitoring

Das Script überwacht automatisch:
- Repository-Änderungen via Git
- Script-Version Updates
- Branch-Status und Synchronisation
- File-spezifische Änderungen

## 🛠️ Technical Details

- **Git Version Checking**: Kombiniert Tags, Commits, und File-Tracking
- **Network Optimization**: Intelligentes Fetching mit Caching
- **Error Recovery**: Automatic Cleanup und Rollback-Funktionen
- **Performance**: Minimale Network-Calls, optimierte Git-Operationen

## 📝 Contributing

1. Fork das Repository
2. Create feature branch: `start_feature your-feature`
3. Make changes and test
4. Commit: `quick_commit "Your changes"`
5. Finish feature: `finish_feature your-feature`
6. Create Pull Request

## 📄 License

MIT License - see LICENSE file for details.

---

**Professional Git Repository Management für OpenWRT Builder** 🚀
EOF

    # Create CHANGELOG.md
    cat > "$TARGET_DIR/CHANGELOG.md" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Professional git version checking system
- Automatic self-update mechanism  
- Git workflow management tools
- Comprehensive validation system

## [1.0.0] - 2025-08-20

### Added
- Initial release
- Basic git clone functionality
- Permission management
- Directory validation

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A
EOF

    print_success "Created project documentation files"
}

################################################################################
### MAIN SETUP FUNCTIONS
################################################################################

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root or with sudo"
    fi
    
    # Check git
    if ! command -v git >/dev/null 2>&1; then
        error_exit "Git is not installed"
    fi
    
    # Check target directory
    if [ ! -d "$TARGET_DIR" ]; then
        error_exit "Target directory $TARGET_DIR does not exist. Run gitclone.sh first."
    fi
    
    if [ ! -d "$TARGET_DIR/.git" ]; then
        error_exit "Target directory is not a git repository"
    fi
    
    print_success "Prerequisites check passed"
}

setup_git_structure() {
    print_info "Setting up Git repository structure..."
    
    cd "$TARGET_DIR"
    
    # Ensure we're on main branch
    git checkout main 2>/dev/null || git checkout -b main
    
    # Create develop branch if it doesn't exist
    if ! git show-ref --verify --quiet refs/heads/develop; then
        git checkout -b develop
        print_success "Created develop branch"
    else
        print_info "Develop branch already exists"
    fi
    
    # Set up remote tracking
    git branch --set-upstream-to=origin/main main 2>/dev/null || true
    git branch --set-upstream-to=origin/develop develop 2>/dev/null || true
    
    print_success "Git structure setup completed"
}

update_gitclone_script() {
    print_info "Ensuring gitclone.sh has latest professional features..."
    
    # Check if gitclone.sh needs updating with git version functions
    if ! grep -q "check_git_version" "$TARGET_DIR/gitclone.sh" 2>/dev/null; then
        print_warning "gitclone.sh needs professional git functions"
        
        if [ -f "/root/gitclone.sh" ]; then
            if grep -q "check_git_version" "/root/gitclone.sh"; then
                if ask_yes_no "Copy updated gitclone.sh from /root/?" "yes"; then
                    cp "/root/gitclone.sh" "$TARGET_DIR/gitclone.sh"
                    print_success "Updated gitclone.sh with professional features"
                fi
            fi
        fi
    else
        print_success "gitclone.sh already has professional features"
    fi
}

commit_initial_setup() {
    print_info "Committing initial professional setup..."
    
    cd "$TARGET_DIR"
    
    # Add all new files
    git add .
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        print_info "No changes to commit"
        return 0
    fi
    
    # Commit changes
    git commit -m "Add professional git workflow and documentation

- Added git-workflow.sh management script
- Created comprehensive documentation
- Added .gitignore for clean repository
- Setup professional development structure"
    
    print_success "Initial setup committed"
}

create_initial_tag() {
    print_info "Creating initial version tag..."
    
    cd "$TARGET_DIR"
    
    # Check current version from script
    local current_version=""
    if [ -f "gitclone.sh" ]; then
        current_version=$(grep "^SCRIPT_VERSION=" gitclone.sh | cut -d'"' -f2)
    fi
    
    if [ -n "$current_version" ]; then
        local tag_name="v$current_version"
        
        # Check if tag already exists
        if ! git tag -l | grep -q "^$tag_name$"; then
            git tag -a "$tag_name" -m "Professional Git Management System

Features:
- Automatic git version checking
- Self-updating mechanism  
- Professional workflow management
- Comprehensive validation system"
            
            print_success "Created initial tag: $tag_name"
            
            if ask_yes_no "Push tag to remote?" "yes"; then
                git push origin "$tag_name" 2>/dev/null && print_success "Tag pushed to remote"
            fi
        else
            print_info "Tag $tag_name already exists"
        fi
    else
        print_warning "Could not determine script version"
    fi
}

push_to_remote() {
    print_info "Pushing changes to remote repository..."
    
    cd "$TARGET_DIR"
    
    # Push main branch
    if git push origin main 2>/dev/null; then
        print_success "Pushed main branch"
    else
        print_warning "Could not push main branch (no remote or permission issue)"
    fi
    
    # Push develop branch
    if git push origin develop 2>/dev/null; then
        print_success "Pushed develop branch"
    else
        print_warning "Could not push develop branch"
    fi
    
    # Push tags
    if git push origin --tags 2>/dev/null; then
        print_success "Pushed tags"
    else
        print_warning "Could not push tags"
    fi
}

show_final_summary() {
    print_header "PROFESSIONAL GIT SETUP COMPLETED"
    
    cd "$TARGET_DIR"
    
    print_info "Project Status:"
    echo "  • Repository: $TARGET_DIR"
    echo "  • Current Branch: $(git branch --show-current)"
    
    if [ -f "gitclone.sh" ]; then
        local version=$(grep "^SCRIPT_VERSION=" gitclone.sh | cut -d'"' -f2)
        echo "  • Script Version: v$version"
    fi
    
    echo ""
    print_info "Available Workflow Commands:"
    echo "  cd $TARGET_DIR"
    echo "  source git-workflow.sh"
    echo "  show_workflow_menu"
    echo ""
    
    print_info "Quick Start Development:"
    echo "  source git-workflow.sh"
    echo "  start_feature my-feature"
    echo "  # ... develop ..."
    echo "  finish_feature my-feature"
    echo "  release_workflow v1.2.0"
    echo ""
    
    print_info "Test Professional Updates:"
    echo "  cd /root"
    echo "  ./gitclone.sh"
    echo "  # Should show professional git checking"
    echo ""
    
    print_success "🚀 Professional Git Management System is ready!"
    
    if [ -d "$BACKUP_DIR" ]; then
        echo ""
        print_info "Backup available at: $BACKUP_DIR"
        if ask_yes_no "Remove backup? (Setup was successful)" "yes"; then
            rm -rf "$BACKUP_DIR"
            print_success "Backup cleaned up"
        fi
    fi
}

################################################################################
### MAIN EXECUTION
################################################################################

main() {
    print_header "Professional Git Setup for OpenWRT gitclone.sh v$SETUP_VERSION"
    
    print_info "This script will:"
    echo "  • Create professional git workflow management"
    echo "  • Setup branch structure (main/develop)"
    echo "  • Add comprehensive documentation"
    echo "  • Create version tags"
    echo "  • Enable automatic git updates"
    echo ""
    
    if ! ask_yes_no "Continue with professional setup?" "yes"; then
        print_info "Setup cancelled"
        exit 0
    fi
    
    # Setup with error handling
    {
        print_step "1" "Checking prerequisites"
        check_prerequisites
        
        print_step "2" "Creating backup"
        create_backup
        
        print_step "3" "Setting up Git structure"
        setup_git_structure
        
        print_step "4" "Creating workflow management script"
        create_git_workflow_script
        
        print_step "5" "Creating project documentation"
        create_project_files
        
        print_step "6" "Updating gitclone.sh script"
        update_gitclone_script
        
        print_step "7" "Committing initial setup"
        commit_initial_setup
        
        print_step "8" "Creating version tag"
        create_initial_tag
        
        print_step "9" "Pushing to remote"
        push_to_remote
        
        print_step "10" "Final summary"
        show_final_summary
        
    } || {
        print_error "Setup failed! Restoring backup..."
        restore_backup
        error_exit "Professional setup failed and was rolled back"
    }
}

# Run main function
main "$@"