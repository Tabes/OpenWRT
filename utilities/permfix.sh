#!/bin/bash
################################################################################
### PermFix - Unix Permission Manager
### Sets correct Unix Permissions for all Project Files and Directories
################################################################################
### Project: PermFix - Permission Management Tool
### Version: 1.0.0
### Author:  Mawage (Workflow Team)
### Date:    2025-08-23
### License: MIT
### Usage:   ./permfix.sh [--help]
################################################################################

SCRIPT_VERSION="1.0.0"
COMMIT="PermFix - Smart Unix Permission Management for Project Files
"
clear


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
### === PERMISSION DETECTION === ###
################################################################################

### Check if file should be executable ###
should_be_executable() {
    local file="$1"
    local basename=$(basename "$file")
    
    ### Check file extension ###
    if [[ "$basename" == *.sh ]]; then
        return 0  ### Shell scripts ###
    fi
    
    ### Check files without extension in specific directories ###
    if [[ ! "$basename" == *.* ]]; then
        ### Check if in scripts or workflow directory ###
        if [[ "$file" == */scripts/* ]] || [[ "$file" == */utilities/* ]] || [[ "$file" == */builder/* ]]; then
            ### Check if it has shebang ###
            if [ -f "$file" ] && head -n1 "$file" 2>/dev/null | grep -q "^#!"; then
                return 0
            fi
        fi
    fi
    
    ### Check specific known executables ###
    case "$basename" in
        gitwork|gitclone|gitmanage|start|build|setup|install|run|deploy|dos2linux|permfix)
            return 0
            ;;
    esac
    
    ### Check if file has shebang (for any file) ###
    if [ -f "$file" ] && head -n1 "$file" 2>/dev/null | grep -q "^#!/.*\(bash\|sh\|python\|perl\|ruby\)"; then
        return 0
    fi
    
    return 1  ### Should not be executable ###
}

### Get current permissions in octal ###
get_permissions() {
    local file="$1"
    stat -c "%a" "$file" 2>/dev/null
}

### Check if permissions are correct ###
check_permissions() {
    local file="$1"
    local current_perm
    local expected_perm
    
    if [ -d "$file" ]; then
        current_perm=$(get_permissions "$file")
        expected_perm="755"
    elif [ -f "$file" ]; then
        current_perm=$(get_permissions "$file")
        if should_be_executable "$file"; then
            expected_perm="755"
        else
            expected_perm="644"
        fi
    else
        return 2  ### Not a regular file or directory ###
    fi
    
    if [ "$current_perm" = "$expected_perm" ]; then
        return 0  ### Permissions are correct ###
    else
        return 1  ### Permissions need fixing ###
    fi
}


################################################################################
### === OWNERSHIP MANAGEMENT === ###
################################################################################

### Get current owner ###
get_owner() {
    local file="$1"
    stat -c "%U:%G" "$file" 2>/dev/null
}

### Set ownership using helper.sh functions ###
set_ownership() {
    local file="$1"
    local owner="${2:-$USER:$USER}"
    
    if is_root; then
        if chown "$owner" "$file" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        ### Not root, cannot change ownership ###
        return 2
    fi
}


################################################################################
### === PERMISSION FIXING === ###
################################################################################

### Fix single file permissions ###
fix_file_permissions() {
    local file="$1"
    local verbose="${2:-false}"
    local dry_run="${3:-false}"
    
    ### Check what type of file it is ###
    if [ -d "$file" ]; then
        ### Directory ###
        local current_perm=$(get_permissions "$file")
        if [ "$current_perm" != "755" ]; then
            if [ "$dry_run" = "true" ]; then
                echo "Would set: $file -> 755 (directory)"
                return 0
            fi
            
            if chmod 755 "$file" 2>/dev/null; then
                [ "$verbose" = "true" ] && print_check "Directory: ${file#$PROJECT_ROOT/} [755]"
                return 0
            else
                [ "$verbose" = "true" ] && print_cross "Failed: ${file#$PROJECT_ROOT/}"
                return 1
            fi
        fi
    elif [ -f "$file" ]; then
        ### Regular file ###
        local current_perm=$(get_permissions "$file")
        local target_perm
        
        if should_be_executable "$file"; then
            target_perm="755"
        else
            target_perm="644"
        fi
        
        if [ "$current_perm" != "$target_perm" ]; then
            if [ "$dry_run" = "true" ]; then
                echo "Would set: $file -> $target_perm"
                return 0
            fi
            
            if chmod "$target_perm" "$file" 2>/dev/null; then
                if [ "$verbose" = "true" ]; then
                    if [ "$target_perm" = "755" ]; then
                        print_check "Executable: ${file#$PROJECT_ROOT/} [755]"
                    else
                        print_check "File: ${file#$PROJECT_ROOT/} [644]"
                    fi
                fi
                return 0
            else
                [ "$verbose" = "true" ] && print_cross "Failed: ${file#$PROJECT_ROOT/}"
                return 1
            fi
        fi
    fi
    
    return 0
}

### Fix all project permissions ###
fix_project_permissions() {
    local project_dir="${1:-$PROJECT_ROOT}"
    local verbose="${2:-false}"
    local dry_run="${3:-false}"
    local fix_owner="${4:-false}"
    local owner="${5:-$USER:$USER}"
    
    print_header "Fixing Permissions in $project_dir"
    
    ### Statistics ###
    local total_dirs=0
    local fixed_dirs=0
    local total_files=0
    local fixed_files=0
    local fixed_exec=0
    local failed=0
    
    ### Dry run message ###
    if [ "$dry_run" = "true" ]; then
        print_warning "DRY-RUN MODE: No files will be modified"
        echo ""
    fi
    
    ### Fix ownership if requested and running as root ###
    if [ "$fix_owner" = "true" ] && is_root; then
        print_info "Setting ownership to $owner..."
        if [ "$dry_run" = "true" ]; then
            echo "Would set ownership: $project_dir -> $owner"
        else
            if chown -R "$owner" "$project_dir" 2>/dev/null; then
                print_success "Ownership set to $owner"
            else
                print_warning "Could not set ownership"
            fi
        fi
        echo ""
    fi
    
    ### Process directories first ###
    print_info "Processing directories..."
    while IFS= read -r dir; do
        ((total_dirs++))
        
        ### Show progress using helper.sh ###
        if [ "$verbose" = "false" ]; then
            show_progress_bar "$total_dirs" 100
        fi
        
        local current_perm=$(get_permissions "$dir")
        if [ "$current_perm" != "755" ]; then
            if [ "$dry_run" = "true" ]; then
                [ "$verbose" = "true" ] && echo "Would fix: ${dir#$project_dir/} ($current_perm -> 755)"
            else
                if chmod 755 "$dir" 2>/dev/null; then
                    ((fixed_dirs++))
                    [ "$verbose" = "true" ] && print_check "Fixed: ${dir#$project_dir/} [755]"
                else
                    ((failed++))
                    [ "$verbose" = "true" ] && print_cross "Failed: ${dir#$project_dir/}"
                fi
            fi
        fi
    done < <(find "$project_dir" -type d)
    
    ### Clear progress line ###
    [ "$verbose" = "false" ] && printf "\r                                          \r"
    
    ### Process files ###
    print_info "Processing files..."
    while IFS= read -r file; do
        ((total_files++))
        
        ### Show progress using helper.sh ###
        if [ "$verbose" = "false" ]; then
            show_progress_bar "$total_files" 100
        fi
        
        local current_perm=$(get_permissions "$file")
        local target_perm
        
        if should_be_executable "$file"; then
            target_perm="755"
        else
            target_perm="644"
        fi
        
        if [ "$current_perm" != "$target_perm" ]; then
            if [ "$dry_run" = "true" ]; then
                [ "$verbose" = "true" ] && echo "Would fix: ${file#$project_dir/} ($current_perm -> $target_perm)"
            else
                if chmod "$target_perm" "$file" 2>/dev/null; then
                    ((fixed_files++))
                    [ "$target_perm" = "755" ] && ((fixed_exec++))
                    [ "$verbose" = "true" ] && print_check "Fixed: ${file#$project_dir/} [$target_perm]"
                else
                    ((failed++))
                    [ "$verbose" = "true" ] && print_cross "Failed: ${file#$project_dir/}"
                fi
            fi
        fi
    done < <(find "$project_dir" -type f)
    
    ### Clear progress line ###
    [ "$verbose" = "false" ] && printf "\r                                          \r"
    
    ### Show summary ###
    echo ""
    print_header "Permission Fix Summary"
    
    if [ "$dry_run" = "true" ]; then
        print_warning "DRY-RUN COMPLETE: No files were modified"
        print_info "Remove --dry-run to apply changes"
        echo ""
    fi
    
    print_info "Directories processed:    $total_dirs"
    [ $fixed_dirs -gt 0 ] && print_success "Directories fixed:        $fixed_dirs"
    
    print_info "Files processed:          $total_files"
    [ $fixed_files -gt 0 ] && print_success "Files fixed:              $fixed_files"
    [ $fixed_exec -gt 0 ] && print_success "Made executable:          $fixed_exec"
    
    if [ $failed -gt 0 ]; then
        print_error "Failed operations:        $failed"
    fi
    
    if [ "$dry_run" != "true" ]; then
        if [ $fixed_dirs -gt 0 ] || [ $fixed_files -gt 0 ]; then
            echo ""
            print_success "Successfully fixed permissions for $((fixed_dirs + fixed_files)) items"
        else
            echo ""
            print_success "All permissions are already correct"
        fi
    fi
}


################################################################################
### === PERMISSION CHECKING === ###
################################################################################

### Check project permissions ###
check_project_permissions() {
    local project_dir="${1:-$PROJECT_ROOT}"
    
    print_header "Checking Permissions in $project_dir"
    
    local incorrect_dirs=0
    local incorrect_files=0
    local missing_exec=0
    local wrong_exec=0
    local dir_list=()
    local file_list=()
    local exec_list=()
    local wrong_list=()
    
    ### Check directories ###
    print_info "Scanning directories..."
    while IFS= read -r dir; do
        local perm=$(get_permissions "$dir")
        if [ "$perm" != "755" ]; then
            ((incorrect_dirs++))
            dir_list+=("${dir#$project_dir/} [$perm should be 755]")
        fi
    done < <(find "$project_dir" -type d)
    
    ### Check files ###
    print_info "Scanning files..."
    while IFS= read -r file; do
        local perm=$(get_permissions "$file")
        
        if should_be_executable "$file"; then
            if [ "$perm" != "755" ]; then
                ((missing_exec++))
                exec_list+=("${file#$project_dir/} [$perm should be 755]")
            fi
        else
            if [ "$perm" = "755" ] || [[ "$perm" == *7* ]]; then
                ((wrong_exec++))
                wrong_list+=("${file#$project_dir/} [$perm should be 644]")
            elif [ "$perm" != "644" ]; then
                ((incorrect_files++))
                file_list+=("${file#$project_dir/} [$perm should be 644]")
            fi
        fi
    done < <(find "$project_dir" -type f)
    
    ### Summary ###
    echo ""
    print_header "Permission Check Summary"
    
    local total_issues=$((incorrect_dirs + incorrect_files + missing_exec + wrong_exec))
    
    if [ $total_issues -eq 0 ]; then
        print_success "All permissions are correct! ✨"
    else
        print_warning "Found $total_issues permission issues:"
        echo ""
        
        if [ $incorrect_dirs -gt 0 ]; then
            print_error "$incorrect_dirs directories with wrong permissions:"
            for item in "${dir_list[@]}"; do
                echo "  📁 $item"
            done
            echo ""
        fi
        
        if [ $incorrect_files -gt 0 ]; then
            print_error "$incorrect_files files with wrong permissions:"
            for item in "${file_list[@]}"; do
                echo "  📄 $item"
            done
            echo ""
        fi
        
        if [ $missing_exec -gt 0 ]; then
            print_error "$missing_exec files should be executable:"
            for item in "${exec_list[@]}"; do
                echo "  🔧 $item"
            done
            echo ""
        fi
        
        if [ $wrong_exec -gt 0 ]; then
            print_error "$wrong_exec files should not be executable:"
            for item in "${wrong_list[@]}"; do
                echo "  ⚠️ $item"
            done
            echo ""
        fi
        
        print_info "Run without --check to fix these issues"
    fi
    
    return $total_issues
}


################################################################################
### === SPECIAL HANDLERS === ###
################################################################################

### Fix git hooks permissions ###
fix_git_hooks() {
    local git_dir="${1:-$PROJECT_ROOT/.git}"
    
    if [ ! -d "$git_dir/hooks" ]; then
        print_info "No Git hooks directory found"
        return 0
    fi
    
    print_info "Fixing Git hooks permissions..."
    
    local fixed=0
    for hook in "$git_dir/hooks"/*; do
        if [ -f "$hook" ] && [[ ! "$hook" == *.sample ]]; then
            if chmod 755 "$hook" 2>/dev/null; then
                ((fixed++))
                print_check "Git hook: $(basename "$hook") [755]"
            fi
        fi
    done
    
    if [ $fixed -gt 0 ]; then
        print_success "Fixed $fixed Git hooks"
    else
        print_info "All Git hooks already have correct permissions"
    fi
}


################################################################################
### === UTILITY FUNCTIONS === ###
################################################################################

### Validate command line options using helper.sh functions ###
validate_options() {
    local path="$1"
    local owner="$2"
    
    ### Validate path using helper.sh ###
    validate_directory "$path" false || return 1
    
    ### Check write permissions using helper.sh ###
    if ! validate_permissions "$path" "w"; then
        print_warning "No write permission for: $path"
        print_info "You may need to run with sudo"
        return 1
    fi
    
    ### Validate owner format if provided ###
    if [ -n "$owner" ] && [[ ! "$owner" =~ ^[a-zA-Z0-9_-]+:[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid owner format: $owner (should be user:group)"
        return 1
    fi
    
    return 0
}


################################################################################
### === MENU AND HELP === ###
################################################################################

### Show usage Information ###
show_menu() {
    print_header "PermFix - Smart Unix Permission Manager"
    
    echo "📋 DESCRIPTION:"
    echo "    PermFix intelligently sets correct Unix permissions for all project files."
    echo "    Automatically detects executables and applies appropriate permissions."
    echo ""
    echo "📌 USAGE:"
    echo "    $0 [OPTIONS]"
    echo ""
    echo "🔧 OPTIONS:"
    echo "    -h, --help           Show this help message"
    echo "    -c, --check          Only check permissions without fixing"
    echo "    -v, --verbose        Show detailed output"
    echo "    -d, --dry-run        Preview changes without modifying files"
    echo "    -o, --owner <owner>  Set ownership (requires root, format: user:group)"
    echo "    -p, --path <dir>     Target directory (default: project root)"
    echo "    --git-hooks          Also fix Git hooks permissions"
    echo "    --sudo               Re-run with sudo if needed"
    echo ""
    echo "🔐 PERMISSION RULES:"
    echo "    Directories:         755 (rwxr-xr-x) - Read/write/execute for owner, read/execute for others"
    echo "    Shell scripts (.sh): 755 (rwxr-xr-x) - Executable"
    echo "    Files with shebang:  755 (rwxr-xr-x) - Executable"
    echo "    Regular files:       644 (rw-r--r--) - Read/write for owner, read-only for others"
    echo "    Git hooks:           755 (rwxr-xr-x) - Executable"
    echo ""
    echo "🎯 EXECUTABLE DETECTION:"
    echo "    • *.sh files (shell scripts)"
    echo "    • Files with shebang (#!/bin/bash, #!/usr/bin/python, etc.)"
    echo "    • Known executables (start, build, setup, install, etc.)"
    echo "    • Files in scripts/, utilities/, builder/ directories with shebang"
    echo ""
    echo "📊 EXAMPLES:"
    echo "    $0                           # Fix all permissions in project"
    echo "    $0 --check                   # Only check for permission issues"
    echo "    $0 --verbose                 # Show detailed progress"
    echo "    $0 --dry-run                 # Preview what would be changed"
    echo "    $0 --owner user:group        # Set ownership (requires root)"
    echo "    $0 --path /opt/project       # Fix specific directory"
    echo "    $0 --git-hooks               # Include Git hooks"
    echo "    $0 --sudo                    # Re-run with elevated privileges"
    echo ""
    echo "💡 TIPS:"
    echo "    • Run with --check first to see what needs fixing"
    echo "    • Use --dry-run to preview changes before applying"
    echo "    • Use --sudo for system directories or when ownership changes needed"
    echo "    • Git hooks are automatically made executable with --git-hooks"
    echo ""
}

### Show quick help ###
show_quick_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Try '$0 --help' for more information."
}

### Show version information ###
show_version() {
    echo "PermFix v${SCRIPT_VERSION}"
    echo "Smart Unix Permission Manager"
    echo "Copyright (c) 2025 Mawage (Workflow Team)"
    echo "License: MIT"
}

### Interactive menu for permissions ###
show_interactive_menu() {
    print_header "PermFix - Interactive Permission Manager"
    
    echo "Select an action:"
    echo ""
    echo "  1) Check permissions (scan only)"
    echo "  2) Fix all permissions"
    echo "  3) Fix permissions with verbose output"
    echo "  4) Dry-run (preview changes)"
    echo "  5) Fix Git hooks permissions"
    echo "  6) Set ownership (requires root)"
    echo "  7) Fix specific directory"
    echo "  8) Show detailed help"
    echo "  9) Exit"
    echo ""
    
    local choice=$(ask_input "Enter your choice" "1" "validate_menu_choice")
    
    case $choice in
        1)
            print_info "Checking permissions..."
            check_project_permissions "$PROJECT_ROOT"
            ;;
        2)
            print_info "Fixing permissions..."
            fix_project_permissions "$PROJECT_ROOT" false false false
            ;;
        3)
            print_info "Fixing permissions with verbose output..."
            fix_project_permissions "$PROJECT_ROOT" true false false
            ;;
        4)
            print_info "Running in dry-run mode..."
            fix_project_permissions "$PROJECT_ROOT" true true false
            ;;
        5)
            print_info "Fixing Git hooks permissions..."
            fix_git_hooks "$PROJECT_ROOT/.git"
            ;;
        6)
            if is_root; then
                local owner=$(ask_input "Enter owner (user:group)" "$USER:$USER")
                print_info "Setting ownership to $owner..."
                fix_project_permissions "$PROJECT_ROOT" true false true "$owner"
            else
                print_warning "Root privileges required for ownership changes"
                if ask_yes_no "Re-run with sudo?"; then
                    exec sudo "$0" --interactive
                fi
            fi
            ;;
        7)
            local path=$(ask_input "Enter directory path" "$PROJECT_ROOT")
            if validate_directory "$path" false; then
                print_info "Fixing permissions in $path..."
                fix_project_permissions "$path" true false false
            else
                print_error "Invalid directory: $path"
            fi
            ;;
        8)
            show_menu
            ;;
        9)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please select 1-9."
            pause "Press Enter to continue..."
            show_interactive_menu
            ;;
    esac
    
    echo ""
    pause "Press Enter to continue..."
    show_interactive_menu
}

### Validate menu choice ###
validate_menu_choice() {
    local choice="$1"
    [[ "$choice" =~ ^[1-9]$ ]]
}


################################################################################
### === MAIN EXECUTION === ###
################################################################################

### Parse Command Line Arguments ###
parse_arguments() {
    ### Default values ###
    local action="fix"
    local verbose=false
    local dry_run=false
    local check_only=false
    local fix_owner=false
    local owner="$USER:$USER"
    local target_path="$PROJECT_ROOT"
    local fix_git_hooks=false
    local interactive=false
    
    ### Store original arguments for logging ###
    local ORIGINAL_ARGS=("$@")
    
    ### Parse arguments ###
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_menu
                exit 0
                ;;
            -V|--version)
                show_version
                exit 0
                ;;
            -c|--check)
                check_only=true
                action="check"
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -d|--dry-run)
                dry_run=true
                verbose=true  ### Dry-run implies verbose ###
                shift
                ;;
            -o|--owner)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    print_error "Option --owner requires an argument"
                    show_quick_help
                    exit 1
                fi
                fix_owner=true
                owner="$2"
                shift 2
                ;;
            -p|--path)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    print_error "Option --path requires an argument"
                    show_quick_help
                    exit 1
                fi
                target_path="$2"
                shift 2
                ;;
            --git-hooks)
                fix_git_hooks=true
                shift
                ;;
            --interactive)
                interactive=true
                action="interactive"
                shift
                ;;
            --sudo)
                ### Re-run script with sudo ###
                if [[ $EUID -ne 0 ]]; then
                    print_info "Re-running with sudo privileges..."
                    exec sudo "$0" "${ORIGINAL_ARGS[@]}"
                fi
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_quick_help
                exit 1
                ;;
            *)
                ### Treat as target path if no option ###
                target_path="$1"
                shift
                ;;
        esac
    done
    
    ### Validate options ###
    if ! validate_options "$target_path" "$owner"; then
        exit 1
    fi
    
    ### Export variables for use in other functions ###
    export VERBOSE="$verbose"
    export DRY_RUN="$dry_run"
    export FIX_OWNER="$fix_owner"
    export OWNER="$owner"
    export TARGET_PATH="$target_path"
    export FIX_GIT_HOOKS="$fix_git_hooks"
    
    ### Log action if verbose ###
    if [ "$verbose" = true ]; then
        print_header "Configuration"
        print_info "Action:       $action"
        print_info "Target Path:  $target_path"
        print_info "Verbose:      $verbose"
        print_info "Dry Run:      $dry_run"
        print_info "Fix Owner:    $fix_owner"
        [ "$fix_owner" = true ] && print_info "Owner:        $owner"
        print_info "Git Hooks:    $fix_git_hooks"
        echo ""
    fi
    
    ### Execute action based on parsed arguments ###
    case "$action" in
        check)
            check_project_permissions "$target_path"
            local result=$?
            if [ $result -gt 0 ]; then
                exit 1
            fi
            ;;
        interactive)
            show_interactive_menu
            ;;
        fix)
            ### Show what will be done in dry-run mode ###
            if [ "$dry_run" = true ]; then
                print_warning "DRY-RUN MODE: No files will be modified"
                echo ""
            fi
            
            ### Fix permissions ###
            fix_project_permissions "$target_path" "$verbose" "$dry_run" "$fix_owner" "$owner"
            
            ### Fix git hooks if requested ###
            if [ "$fix_git_hooks" = true ]; then
                echo ""
                fix_git_hooks "$target_path/.git"
            fi
            
            ### Show completion message ###
            if [ "$dry_run" = true ]; then
                echo ""
                print_warning "DRY-RUN COMPLETE: No files were modified"
                print_info "Remove --dry-run to apply changes"
            fi
            ;;
        *)
            print_error "Unknown action: $action"
            exit 1
            ;;
    esac
}

### Main function ###
main() {
    ### Load configuration ###
    load_config
    
    ### Check if no arguments provided ###
    if [ $# -eq 0 ]; then
        ### Show interactive menu if no arguments ###
        show_interactive_menu
    else
        ### Parse and execute arguments ###
        parse_arguments "$@"
    fi
    
    ### Return success ###
    exit 0
}

### Initialize ###
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    ### Running directly ###
    main "$@"
else
    ### Being sourced ###
    load_config
    print_success "PermFix loaded. Type 'show_interactive_menu' for interactive mode."
fi