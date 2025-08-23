#!/bin/bash
################################################################################
### Project Fix Manager - Complete Project File Manager
### Orchestrates CRLF Conversion and Permission fixing for Entire Projects
################################################################################
### Project: Universal Project Fix Manager
### Version: 1.0.0
### Author:  Mawage (Workflow Team)
### Date:    2025-08-23
### License: MIT
### Usage:   ./fix-project.sh [--help]
################################################################################

SCRIPT_VERSION="1.0.0"
COMMIT="Complete project fixing: CRLF conversion + permission management"
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
### === TOOL VALIDATION === ###
################################################################################

### Check if required tools exist ###
check_required_tools() {
    local project_dir="${1:-$PROJECT_ROOT}"
    local dos2linux_script="$WORKFLOW_DIR/dos2linux.sh"
    local permfix_script="$WORKFLOW_DIR/permfix.sh"
    local missing_tools=()
    
    print_header "Validating Required Tools"
    
    ### Check dos2linux.sh ###
    if validate_file "$dos2linux_script" false; then
        if validate_permissions "$dos2linux_script" "x"; then
            print_check "dos2linux.sh found and executable"
        else
            print_warning "dos2linux.sh found but not executable - fixing..."
            chmod +x "$dos2linux_script" 2>/dev/null || missing_tools+=("dos2linux.sh (permission fix failed)")
        fi
    else
        missing_tools+=("dos2linux.sh")
    fi
    
    ### Check permfix.sh ###
    if validate_file "$permfix_script" false; then
        if validate_permissions "$permfix_script" "x"; then
            print_check "permfix.sh found and executable"
        else
            print_warning "permfix.sh found but not executable - fixing..."
            chmod +x "$permfix_script" 2>/dev/null || missing_tools+=("permfix.sh (permission fix failed)")
        fi
    else
        missing_tools+=("permfix.sh")
    fi
    
    ### Report missing tools ###
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            print_cross "$tool"
        done
        echo ""
        print_info "Expected locations:"
        print_info "  dos2linux.sh: $dos2linux_script"
        print_info "  permfix.sh:   $permfix_script"
        return 1
    fi
    
    print_success "All required tools are available and executable"
    return 0
}


################################################################################
### === LINE ENDING CONVERSION === ###
################################################################################

### Run dos2linux conversion ###
run_dos2linux() {
    local project_dir="${1:-$PROJECT_ROOT}"
    local verbose="${2:-false}"
    local dry_run="${3:-false}"
    local method="${4:-auto}"
    local dos2linux_script="$WORKFLOW_DIR/dos2linux.sh"
    
    print_header "Step 1: Converting Line Endings (CRLF → LF)"
    
    ### Build dos2linux command ###
    local cmd="\"$dos2linux_script\""
    local args=()
    
    ### Add path ###
    args+=("--path" "$project_dir")
    
    ### Add method ###
    args+=("--method" "$method")
    
    ### Add verbose flag ###
    [ "$verbose" = "true" ] && args+=("--verbose")
    
    ### Add dry-run flag ###
    [ "$dry_run" = "true" ] && args+=("--dry-run")
    
    ### Show command in verbose mode ###
    if [ "$verbose" = "true" ]; then
        print_info "Executing: $cmd ${args[*]}"
        echo ""
    fi
    
    ### Execute dos2linux ###
    if "$dos2linux_script" "${args[@]}"; then
        print_success "Line ending conversion completed successfully"
        return 0
    else
        print_error "Line ending conversion failed"
        return 1
    fi
}

### Check line endings only ###
check_line_endings() {
    local project_dir="${1:-$PROJECT_ROOT}"
    local dos2linux_script="$WORKFLOW_DIR/dos2linux.sh"
    
    print_header "Checking Line Endings"
    
    ### Execute dos2linux in check mode ###
    if "$dos2linux_script" --check --path "$project_dir"; then
        return 0  ### No issues found ###
    else
        return 1  ### Issues found ###
    fi
}


################################################################################
### === PERMISSION FIXING === ###
################################################################################

### Run permission fixing ###
run_permfix() {
    local project_dir="${1:-$PROJECT_ROOT}"
    local verbose="${2:-false}"
    local dry_run="${3:-false}"
    local fix_ownership="${4:-false}"
    local owner="${5:-$USER:$USER}"
    local fix_git_hooks="${6:-false}"
    local permfix_script="$WORKFLOW_DIR/permfix.sh"
    
    print_header "Step 2: Fixing File Permissions"
    
    ### Build permfix command ###
    local cmd="\"$permfix_script\""
    local args=()
    
    ### Add path ###
    args+=("--path" "$project_dir")
    
    ### Add verbose flag ###
    [ "$verbose" = "true" ] && args+=("--verbose")
    
    ### Add dry-run flag ###
    [ "$dry_run" = "true" ] && args+=("--dry-run")
    
    ### Add ownership ###
    if [ "$fix_ownership" = "true" ]; then
        args+=("--owner" "$owner")
    fi
    
    ### Add git hooks ###
    [ "$fix_git_hooks" = "true" ] && args+=("--git-hooks")
    
    ### Show command in verbose mode ###
    if [ "$verbose" = "true" ]; then
        print_info "Executing: $cmd ${args[*]}"
        echo ""
    fi
    
    ### Execute permfix ###
    if "$permfix_script" "${args[@]}"; then
        print_success "Permission fixing completed successfully"
        return 0
    else
        print_error "Permission fixing failed"
        return 1
    fi
}

### Check permissions only ###
check_permissions() {
    local project_dir="${1:-$PROJECT_ROOT}"
    local permfix_script="$WORKFLOW_DIR/permfix.sh"
    
    print_header "Checking File Permissions"
    
    ### Execute permfix in check mode ###
    if "$permfix_script" --check --path "$project_dir"; then
        return 0  ### No issues found ###
    else
        return 1  ### Issues found ###
    fi
}


################################################################################
### === COMPLETE PROJECT FIXING === ###
################################################################################

### Fix entire project ###
fix_complete_project() {
    local project_dir="${1:-$PROJECT_ROOT}"
    local verbose="${2:-false}"
    local dry_run="${3:-false}"
    local method="${4:-auto}"
    local fix_ownership="${5:-false}"
    local owner="${6:-$USER:$USER}"
    local fix_git_hooks="${7:-true}"
    local skip_line_endings="${8:-false}"
    local skip_permissions="${9:-false}"
    
    print_header "Complete Project Fix: $project_dir"
    
    ### Show configuration ###
    if [ "$verbose" = "true" ]; then
        print_info "Target directory: $project_dir"
        print_info "Conversion method: $method"
        print_info "Fix ownership: $fix_ownership"
        [ "$fix_ownership" = "true" ] && print_info "Owner: $owner"
        print_info "Fix Git hooks: $fix_git_hooks"
        print_info "Dry run: $dry_run"
        echo ""
    fi
    
    ### Statistics ###
    local steps_completed=0
    local steps_failed=0
    local start_time=$(date +%s)
    
    ### Step 1: Line ending conversion ###
    if [ "$skip_line_endings" != "true" ]; then
        if run_dos2linux "$project_dir" "$verbose" "$dry_run" "$method"; then
            ((steps_completed++))
        else
            ((steps_failed++))
            print_warning "Continuing with permission fixing despite line ending conversion failure..."
        fi
        echo ""
    else
        print_info "Skipping line ending conversion (--skip-crlf specified)"
        echo ""
    fi
    
    ### Step 2: Permission fixing ###
    if [ "$skip_permissions" != "true" ]; then
        if run_permfix "$project_dir" "$verbose" "$dry_run" "$fix_ownership" "$owner" "$fix_git_hooks"; then
            ((steps_completed++))
        else
            ((steps_failed++))
        fi
        echo ""
    else
        print_info "Skipping permission fixing (--skip-permissions specified)"
        echo ""
    fi
    
    ### Final summary ###
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_header "Project Fix Summary"
    
    if [ "$dry_run" = "true" ]; then
        print_warning "DRY-RUN COMPLETE: No files were modified"
        print_info "Remove --dry-run to apply all changes"
        echo ""
    fi
    
    print_info "Steps completed: $steps_completed"
    [ $steps_failed -gt 0 ] && print_error "Steps failed: $steps_failed"
    print_info "Duration: $(format_duration $duration)"
    
    if [ "$dry_run" != "true" ]; then
        if [ $steps_failed -eq 0 ]; then
            echo ""
            print_success "🎉 Project fix completed successfully!"
            print_info "All files have correct line endings and permissions"
        else
            echo ""
            print_warning "Project fix completed with some failures"
            print_info "Check the output above for details"
        fi
    fi
    
    return $steps_failed
}

### Check entire project ###
check_complete_project() {
    local project_dir="${1:-$PROJECT_ROOT}"
    
    print_header "Complete Project Check: $project_dir"
    
    local line_ending_issues=0
    local permission_issues=0
    
    ### Check line endings ###
    if ! check_line_endings "$project_dir"; then
        line_ending_issues=1
    fi
    echo ""
    
    ### Check permissions ###
    if ! check_permissions "$project_dir"; then
        permission_issues=1
    fi
    echo ""
    
    ### Summary ###
    print_header "Project Check Summary"
    
    local total_issues=$((line_ending_issues + permission_issues))
    
    if [ $total_issues -eq 0 ]; then
        print_success "✨ Project is in perfect condition!"
        print_info "All files have correct line endings and permissions"
    else
        print_warning "Found issues that need fixing:"
        [ $line_ending_issues -gt 0 ] && print_cross "Files with Windows line endings (CRLF)"
        [ $permission_issues -gt 0 ] && print_cross "Files with incorrect permissions"
        echo ""
        print_info "Run without --check to fix these issues"
    fi
    
    return $total_issues
}


################################################################################
### === UTILITY FUNCTIONS === ###
################################################################################

### Validate command line options using helper.sh functions ###
validate_options() {
    local method="$1"
    local path="$2"
    local owner="$3"
    
    ### Validate conversion method ###
    case "$method" in
        dos2unix|sed|tr|auto)
            ### Valid method ###
            ;;
        *)
            print_error "Invalid method: $method"
            print_info "Valid methods: dos2unix, sed, tr, auto"
            return 1
            ;;
    esac
    
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
    print_header "Project Fix Manager - Complete Project File Manager"
    
    echo "📋 DESCRIPTION:"
    echo "    Complete project fixing solution that orchestrates CRLF conversion and"
    echo "    permission management. Automatically runs dos2linux.sh and permfix.sh"
    echo "    in the correct sequence to fix all project files."
    echo ""
    echo "📌 USAGE:"
    echo "    $0 [OPTIONS]"
    echo ""
    echo "🔧 OPTIONS:"
    echo "    -h, --help               Show this help message"
    echo "    -c, --check              Only check for issues without fixing"
    echo "    -v, --verbose            Show detailed output"
    echo "    -d, --dry-run            Preview changes without modifying files"
    echo "    -p, --path <dir>         Target directory (default: project root)"
    echo "    -m, --method <type>      CRLF conversion method: dos2unix, sed, tr, auto"
    echo "    -o, --owner <owner>      Set ownership (requires root, format: user:group)"
    echo "    --skip-crlf              Skip line ending conversion"
    echo "    --skip-permissions       Skip permission fixing"
    echo "    --no-git-hooks           Don't fix Git hooks permissions"
    echo "    --sudo                   Re-run with elevated privileges"
    echo ""
    echo "🔄 PROCESSING SEQUENCE:"
    echo "    1. Tool Validation       Check dos2linux.sh and permfix.sh availability"
    echo "    2. Line Ending Fix       Convert Windows CRLF to Unix LF (dos2linux.sh)"
    echo "    3. Permission Fix        Set correct Unix permissions (permfix.sh)"
    echo "    4. Git Hooks Fix         Make Git hooks executable (optional)"
    echo ""
    echo "🎯 WHAT GETS FIXED:"
    echo "    Line Endings:            All text files converted from CRLF to LF"
    echo "    File Permissions:        Scripts → 755, Regular files → 644"
    echo "    Directory Permissions:   All directories → 755"
    echo "    Executables:            Auto-detected and made executable"
    echo "    Git Hooks:              Made executable (if --no-git-hooks not used)"
    echo "    Ownership:              Optional user:group ownership (with --owner)"
    echo ""
    echo "📊 EXAMPLES:"
    echo "    $0                           # Fix entire project (CRLF + permissions)"
    echo "    $0 --check                   # Check for all issues"
    echo "    $0 --verbose                 # Show detailed progress"
    echo "    $0 --dry-run                 # Preview all changes"
    echo "    $0 --path /opt/project       # Fix specific directory"
    echo "    $0 --method dos2unix         # Use specific CRLF conversion method"
    echo "    $0 --owner root:root         # Set ownership (requires root)"
    echo "    $0 --skip-crlf               # Only fix permissions"
    echo "    $0 --skip-permissions        # Only fix line endings"
    echo "    $0 --no-git-hooks            # Skip Git hooks fixing"
    echo ""
    echo "💡 TIPS:"
    echo "    • Run with --check first to see what needs fixing"
    echo "    • Use --dry-run to preview all changes safely"
    echo "    • Use --verbose to see detailed progress from both tools"
    echo "    • Perfect for project setup after cloning from Windows systems"
    echo "    • Automatically detects and uses best available conversion method"
    echo ""
    echo "⚠️  DEPENDENCIES:"
    echo "    • dos2linux.sh must exist in utilities/ directory"
    echo "    • permfix.sh must exist in utilities/ directory"
    echo "    • Both tools must be executable"
    echo ""
}

### Show quick help ###
show_quick_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Try '$0 --help' for more information."
}

### Show version information ###
show_version() {
    echo "Project Fix Manager v${SCRIPT_VERSION}"
    echo "Complete Project File Management Solution"
    echo "Copyright (c) 2025 Mawage (Workflow Team)"
    echo "License: MIT"
}

### Interactive menu ###
show_interactive_menu() {
    print_header "Project Fix Manager - Interactive Mode"
    
    echo "Select an action:"
    echo ""
    echo "  1) Check entire project (scan only)"
    echo "  2) Fix entire project (CRLF + permissions)"
    echo "  3) Fix with verbose output"
    echo "  4) Dry-run (preview all changes)"
    echo "  5) Fix only line endings (CRLF → LF)"
    echo "  6) Fix only permissions"
    echo "  7) Fix specific directory"
    echo "  8) Show detailed help"
    echo "  9) Exit"
    echo ""
    
    local choice=$(ask_input "Enter your choice" "1" "validate_menu_choice")
    
    case $choice in
        1)
            print_info "Checking entire project..."
            check_complete_project "$PROJECT_ROOT"
            ;;
        2)
            print_info "Fixing entire project..."
            fix_complete_project "$PROJECT_ROOT" false false "auto" false "$USER:$USER" true false false
            ;;
        3)
            print_info "Fixing entire project with verbose output..."
            fix_complete_project "$PROJECT_ROOT" true false "auto" false "$USER:$USER" true false false
            ;;
        4)
            print_info "Running complete dry-run..."
            fix_complete_project "$PROJECT_ROOT" true true "auto" false "$USER:$USER" true false false
            ;;
        5)
            print_info "Fixing only line endings..."
            fix_complete_project "$PROJECT_ROOT" true false "auto" false "$USER:$USER" false false true
            ;;
        6)
            print_info "Fixing only permissions..."
            fix_complete_project "$PROJECT_ROOT" true false "auto" false "$USER:$USER" true true false
            ;;
        7)
            local path=$(ask_input "Enter directory path" "$PROJECT_ROOT")
            if validate_directory "$path" false; then
                print_info "Fixing project in $path..."
                fix_complete_project "$path" true false "auto" false "$USER:$USER" true false false
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
    local target_path="$PROJECT_ROOT"
    local method="auto"
    local fix_ownership=false
    local owner="$USER:$USER"
    local fix_git_hooks=true
    local skip_crlf=false
    local skip_permissions=false
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
            -p|--path)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    print_error "Option --path requires an argument"
                    show_quick_help
                    exit 1
                fi
                target_path="$2"
                shift 2
                ;;
            -m|--method)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    print_error "Option --method requires an argument"
                    show_quick_help
                    exit 1
                fi
                method="$2"
                shift 2
                ;;
            -o|--owner)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    print_error "Option --owner requires an argument"
                    show_quick_help
                    exit 1
                fi
                fix_ownership=true
                owner="$2"
                shift 2
                ;;
            --skip-crlf)
                skip_crlf=true
                shift
                ;;
            --skip-permissions)
                skip_permissions=true
                shift
                ;;
            --no-git-hooks)
                fix_git_hooks=false
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
    
    ### Validate skip options ###
    if [ "$skip_crlf" = "true" ] && [ "$skip_permissions" = "true" ]; then
        print_error "Cannot skip both CRLF conversion and permission fixing"
        exit 1
    fi
    
    ### Validate options ###
    if ! validate_options "$method" "$target_path" "$owner"; then
        exit 1
    fi
    
    ### Export variables for use in other functions ###
    export VERBOSE="$verbose"
    export DRY_RUN="$dry_run"
    export METHOD="$method"
    export TARGET_PATH="$target_path"
    export FIX_OWNERSHIP="$fix_ownership"
    export OWNER="$owner"
    export FIX_GIT_HOOKS="$fix_git_hooks"
    export SKIP_CRLF="$skip_crlf"
    export SKIP_PERMISSIONS="$skip_permissions"
    
    ### Log action if verbose ###
    if [ "$verbose" = true ]; then
        print_header "Configuration"
        print_info "Action:            $action"
        print_info "Target Path:       $target_path"
        print_info "Conversion Method: $method"
        print_info "Verbose:           $verbose"
        print_info "Dry Run:           $dry_run"
        print_info "Fix Ownership:     $fix_ownership"
        [ "$fix_ownership" = true ] && print_info "Owner:             $owner"
        print_info "Fix Git Hooks:     $fix_git_hooks"
        print_info "Skip CRLF:         $skip_crlf"
        print_info "Skip Permissions:  $skip_permissions"
        echo ""
    fi
    
    ### Check required tools first ###
    if ! check_required_tools; then
        exit 1
    fi
    echo ""
    
    ### Execute action based on parsed arguments ###
    case "$action" in
        check)
            check_complete_project "$target_path"
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
            
            ### Fix complete project ###
            fix_complete_project "$target_path" "$verbose" "$dry_run" "$method" "$fix_ownership" "$owner" "$fix_git_hooks" "$skip_crlf" "$skip_permissions"
            local result=$?
            
            ### Exit with appropriate code ###
            if [ $result -gt 0 ]; then
                exit 1
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
    print_success "Project Fix Manager loaded. Type 'show_interactive_menu' for interactive mode."
fi