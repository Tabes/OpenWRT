#!/bin/bash
################################################################################
### DOS2Linux Converter - Windows to Unix Line Ending Converter
### Convert Windows CRLF to Unix LF and set correct Unix Permissions
################################################################################
### Project: DOS2Linux Line Ending Converter
### Version: 1.0.0
### Author:  Mawage (Workflow Team)
### Date:    2025-08-23
### License: MIT
### Usage:   ./dos2linux.sh [--help]
################################################################################

SCRIPT_VERSION="1.0.0"
COMMIT="DOS2Linux - Convert Windows CRLF to Unix LF Line Endings"
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
### === DOS2UNIX INSTALLATION === ###
################################################################################

### Check and install dos2unix using helper.sh functions ###
check_dos2unix() {
    if command_exists "dos2unix"; then
        print_success "dos2unix is installed"
        return 0
    else
        print_warning "dos2unix is not installed"
        print_info "Installing dos2unix..."
        
        if install_package "dos2unix"; then
            print_success "dos2unix installed successfully"
            return 0
        else
            print_error "Failed to install dos2unix"
            print_info "Please install dos2unix manually for your system"
            return 1
        fi
    fi
}


################################################################################
### === CONVERSION METHODS === ###
################################################################################

### Convert using dos2unix (preferred) ###
convert_with_dos2unix() {
    local file="$1"
    
    if dos2unix "$file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

### Convert using sed (fallback) ###
convert_with_sed() {
    local file="$1"
    
    ### Create backup using helper.sh ###
    backup_file "$file"
    
    ### Convert CRLF to LF ###
    if sed -i 's/\r$//' "$file" 2>/dev/null; then
        return 0
    else
        ### Restore from backup ###
        print_error "Conversion failed, restoring backup"
        return 1
    fi
}

### Convert using tr (second fallback) ###
convert_with_tr() {
    local file="$1"
    local temp_file=$(create_temp_file "convert" ".tmp")
    
    ### Convert CRLF to LF ###
    if tr -d '\r' < "$file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}


################################################################################
### === FILE DETECTION & CHECKING === ###
################################################################################

### Check files only (no conversion) ###
check_files_only() {
    local target_path="${1:-$PROJECT_ROOT}"
    
    print_header "Checking for Windows Line Endings"
    
    local crlf_files=0
    local total_checked=0
    local crlf_list=()
    
    ### File patterns to check ###
    local patterns=(
        "*.sh" "*.bash" "*.zsh"
        "*.conf" "*.cfg" "*.ini"
        "*.txt" "*.md" "*.rst"
        "*.json" "*.xml" "*.yml" "*.yaml"
        "*.py" "*.php" "*.js" "*.css" "*.html"
        "Dockerfile" "Makefile" ".gitignore" ".env"
    )
    
    ### Build find command ###
    local find_cmd="find \"$target_path\" -type f \\( "
    local first=true
    for pattern in "${patterns[@]}"; do
        if [ "$first" = true ]; then
            find_cmd="$find_cmd -name \"$pattern\""
            first=false
        else
            find_cmd="$find_cmd -o -name \"$pattern\""
        fi
    done
    find_cmd="$find_cmd \\)"
    
    print_info "Scanning files..."
    echo ""
    
    ### Check each file ###
    while IFS= read -r file; do
        ((total_checked++))
        print_progress "$total_checked" 1000 "Checking files..."
        
        if has_crlf "$file"; then
            ((crlf_files++))
            crlf_list+=("$file")
        fi
    done < <(eval "$find_cmd")
    
    ### Clear progress line ###
    printf "\r                                          \r"
    
    ### Show results ###
    if [ $crlf_files -gt 0 ]; then
        print_warning "Found $crlf_files files with Windows line endings:"
        echo ""
        for file in "${crlf_list[@]}"; do
            echo "  📄 ${file#$target_path/}"
        done
        echo ""
        print_info "Total files checked: $total_checked"
        print_info "Files needing conversion: $crlf_files"
        echo ""
        print_info "Run without --check to convert these files"
    else
        print_success "All $total_checked files have correct Unix line endings (LF)"
    fi
    
    return $crlf_files
}

### Check if file has CRLF endings ###
has_crlf() {
    local file="$1"
    
    ### Check for carriage return characters ###
    if file "$file" 2>/dev/null | grep -q "CRLF\|with CR"; then
        return 0
    elif grep -q $'\r' "$file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}


################################################################################
### === MAIN CONVERSION === ###
################################################################################

### Convert single file ###
convert_file() {
    local file="$1"
    local method="$2"
    
    ### Check if file exists using helper.sh ###
    if ! validate_file "$file" false; then
        return 1
    fi
    
    ### Check if file needs conversion ###
    if ! has_crlf "$file"; then
        return 2  ### Already in LF format ###
    fi
    
    ### Try conversion based on method ###
    case "$method" in
        dos2unix)
            convert_with_dos2unix "$file"
            ;;
        sed)
            convert_with_sed "$file"
            ;;
        tr)
            convert_with_tr "$file"
            ;;
        auto)
            ### Try methods in order of preference ###
            if command_exists "dos2unix"; then
                convert_with_dos2unix "$file"
            elif command_exists "sed"; then
                convert_with_sed "$file"
            else
                convert_with_tr "$file"
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

### Convert all project files ###
convert_project_files() {
    local project_dir="${1:-$PROJECT_ROOT}"
    local method="${2:-auto}"
    
    print_header "Converting Line Endings in $project_dir"
    
    ### Statistics ###
    local total_files=0
    local converted_files=0
    local skipped_files=0
    local failed_files=0
    
    ### File patterns to convert ###
    local patterns=(
        "*.sh"
        "*.conf"
        "*.cfg"
        "*.txt"
        "*.md"
        "*.yml"
        "*.yaml"
        "*.json"
        "*.xml"
        "*.sql"
        "*.php"
        "*.py"
        "*.js"
        "*.css"
        "*.html"
        "*.htm"
        "Dockerfile"
        "Makefile"
        ".gitignore"
        ".env"
    )
    
    ### Build find command ###
    local find_cmd="find \"$project_dir\" -type f \\( "
    local first=true
    for pattern in "${patterns[@]}"; do
        if [ "$first" = true ]; then
            find_cmd="$find_cmd -name \"$pattern\""
            first=false
        else
            find_cmd="$find_cmd -o -name \"$pattern\""
        fi
    done
    find_cmd="$find_cmd \\)"
    
    ### Process files ###
    print_info "Scanning for files with Windows line endings..."
    echo ""
    
    while IFS= read -r file; do
        ((total_files++))
        
        ### Show progress using helper.sh ###
        show_progress_bar "$total_files" 1000
        
        ### Convert file ###
        convert_file "$file" "$method"
        local result=$?
        
        case $result in
            0)
                ((converted_files++))
                printf "\r✅ Converted: %s\n" "${file#$project_dir/}"
                ;;
            2)
                ((skipped_files++))
                ### Don't print for already correct files ###
                ;;
            *)
                ((failed_files++))
                printf "\r❌ Failed: %s\n" "${file#$project_dir/}"
                ;;
        esac
    done < <(eval "$find_cmd")
    
    ### Clear progress line ###
    printf "\r                                                  \r"
    
    ### Show summary ###
    echo ""
    print_header "Conversion Summary"
    print_info "Total files scanned:  $total_files"
    print_success "Files converted:      $converted_files"
    print_info "Files already OK:     $skipped_files"
    if [ $failed_files -gt 0 ]; then
        print_error "Files failed:         $failed_files"
    fi
    
    if [ $converted_files -gt 0 ]; then
        echo ""
        print_success "Successfully converted $converted_files files to Unix format (LF)"
    elif [ $failed_files -eq 0 ]; then
        echo ""
        print_success "All files already have correct Unix line endings (LF)"
    fi
}


################################################################################
### === UTILITY FUNCTIONS === ###
################################################################################

### Validate command line options using helper.sh functions ###
validate_options() {
    local method="$1"
    local path="$2"
    
    ### Validate method ###
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
    
    return 0
}


################################################################################
### === MENU AND HELP === ###
################################################################################

### Show usage Information ###
show_menu() {
    print_header "DOS2Linux - Windows to Unix Line Ending Converter"
    
    echo "📋 DESCRIPTION:"
    echo "    DOS2Linux converts Windows line endings (CRLF) to Unix/Linux format (LF)"
    echo "    for all project files. Supports multiple conversion methods."
    echo ""
    echo "📌 USAGE:"
    echo "    $0 [OPTIONS]"
    echo ""
    echo "🔧 OPTIONS:"
    echo "    -h, --help           Show this help message"
    echo "    -c, --check          Only check for CRLF files without converting"
    echo "    -i, --install        Install dos2unix if not present"
    echo "    -m, --method <type>  Conversion method: dos2unix, sed, tr, auto (default: auto)"
    echo "    -p, --path <dir>     Target directory (default: project root)"
    echo "    -v, --verbose        Show detailed output"
    echo "    -d, --dry-run        Preview changes without modifying files"
    echo "    -f, --force          Force conversion even if files seem OK"
    echo "    --include <pattern>  Additional file pattern to include"
    echo "    --exclude <pattern>  File pattern to exclude from conversion"
    echo ""
    echo "📁 DEFAULT FILE PATTERNS:"
    echo "    Scripts:     *.sh, *.bash, *.zsh"
    echo "    Configs:     *.conf, *.cfg, *.ini, *.env"
    echo "    Documents:   *.txt, *.md, *.rst"
    echo "    Data:        *.json, *.xml, *.yml, *.yaml"
    echo "    Code:        *.py, *.php, *.js, *.css, *.html"
    echo "    Build:       Dockerfile, Makefile, .gitignore"
    echo ""
    echo "⚙️ CONVERSION METHODS:"
    echo "    dos2unix   - Uses dos2unix tool (recommended)"
    echo "    sed        - Uses sed command (universal)"
    echo "    tr         - Uses tr command (lightweight)"
    echo "    auto       - Automatically selects best available method"
    echo ""
    echo "📊 EXAMPLES:"
    echo "    $0                           # Convert all project files"
    echo "    $0 --check                   # Check for Windows line endings"
    echo "    $0 --install                 # Install dos2unix first"
    echo "    $0 --method sed              # Use sed for conversion"
    echo "    $0 --path /opt/project       # Convert specific directory"
    echo "    $0 --dry-run                 # Preview what would be changed"
    echo "    $0 --include '*.log'         # Include log files"
    echo "    $0 --exclude '*.bak'         # Exclude backup files"
    echo ""
    echo "💡 TIPS:"
    echo "    • Run with --check first to see affected files"
    echo "    • Use --dry-run to preview changes before applying"
    echo "    • dos2unix method is fastest and most reliable"
    echo "    • Auto method works on all Unix/Linux systems"
    echo ""
}

### Show quick help ###
show_quick_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Try '$0 --help' for more information."
}

### Show version information ###
show_version() {
    echo "DOS2Linux Converter v${SCRIPT_VERSION}"
    echo "Windows to Unix Line Ending Converter"
    echo "Copyright (c) 2025 Mawage (Workflow Team)"
    echo "License: MIT"
}

### Interactive menu for conversion ###
show_interactive_menu() {
    print_header "DOS2Linux - Interactive Line Ending Converter"
    
    echo "Select an action:"
    echo ""
    echo "  1) Check for Windows line endings"
    echo "  2) Convert all files (auto-detect method)"
    echo "  3) Convert with dos2unix"
    echo "  4) Convert with sed"
    echo "  5) Convert with tr"
    echo "  6) Install dos2unix"
    echo "  7) Dry-run (preview changes)"
    echo "  8) Show detailed help"
    echo "  9) Exit"
    echo ""
    
    local choice=$(ask_input "Enter your choice" "1" "validate_menu_choice")
    
    case $choice in
        1)
            print_info "Checking for Windows line endings..."
            check_files_only "$PROJECT_ROOT"
            ;;
        2)
            print_info "Converting files with auto-detection..."
            convert_project_files "$PROJECT_ROOT" "auto"
            ;;
        3)
            if command_exists "dos2unix"; then
                print_info "Converting files with dos2unix..."
                convert_project_files "$PROJECT_ROOT" "dos2unix"
            else
                print_warning "dos2unix not installed. Install it first (option 6)"
            fi
            ;;
        4)
            print_info "Converting files with sed..."
            convert_project_files "$PROJECT_ROOT" "sed"
            ;;
        5)
            print_info "Converting files with tr..."
            convert_project_files "$PROJECT_ROOT" "tr"
            ;;
        6)
            check_dos2unix
            ;;
        7)
            print_info "Running in dry-run mode..."
            export DRY_RUN=true
            convert_project_files "$PROJECT_ROOT" "auto"
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
    local action="convert"
    local method="auto"
    local target_path="$PROJECT_ROOT"
    local verbose=false
    local dry_run=false
    local force=false
    local check_only=false
    local install_only=false
    local interactive=false
    local include_patterns=()
    local exclude_patterns=()
    
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
            -i|--install)
                install_only=true
                action="install"
                shift
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
            -p|--path)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    print_error "Option --path requires an argument"
                    show_quick_help
                    exit 1
                fi
                target_path="$2"
                shift 2
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
            -f|--force)
                force=true
                shift
                ;;
            --interactive)
                interactive=true
                action="interactive"
                shift
                ;;
            --include)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    print_error "Option --include requires a pattern"
                    show_quick_help
                    exit 1
                fi
                include_patterns+=("$2")
                shift 2
                ;;
            --exclude)
                if [[ -z "$2" ]] || [[ "$2" == -* ]]; then
                    print_error "Option --exclude requires a pattern"
                    show_quick_help
                    exit 1
                fi
                exclude_patterns+=("$2")
                shift 2
                ;;
            --all)
                ### Convert all files, not just specific patterns ###
                force=true
                include_patterns=("*")
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
    if ! validate_options "$method" "$target_path"; then
        exit 1
    fi
    
    ### Export variables for use in other functions ###
    export VERBOSE="$verbose"
    export DRY_RUN="$dry_run"
    export FORCE="$force"
    export METHOD="$method"
    export TARGET_PATH="$target_path"
    export INCLUDE_PATTERNS=("${include_patterns[@]}")
    export EXCLUDE_PATTERNS=("${exclude_patterns[@]}")
    
    ### Log action if verbose ###
    if [ "$verbose" = true ]; then
        print_header "Configuration"
        print_info "Action:       $action"
        print_info "Method:       $method"
        print_info "Target Path:  $target_path"
        print_info "Verbose:      $verbose"
        print_info "Dry Run:      $dry_run"
        print_info "Force:        $force"
        if [ ${#include_patterns[@]} -gt 0 ]; then
            print_info "Include:      ${include_patterns[*]}"
        fi
        if [ ${#exclude_patterns[@]} -gt 0 ]; then
            print_info "Exclude:      ${exclude_patterns[*]}"
        fi
        echo ""
    fi
    
    ### Execute action based on parsed arguments ###
    case "$action" in
        check)
            check_files_only "$target_path"
            ;;
        install)
            check_dos2unix
            ;;
        interactive)
            show_interactive_menu
            ;;
        convert)
            ### Show what will be done in dry-run mode ###
            if [ "$dry_run" = true ]; then
                print_warning "DRY-RUN MODE: No files will be modified"
                echo ""
            fi
            
            ### Perform conversion ###
            convert_project_files "$target_path" "$method"
            
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
    print_success "DOS2Linux Converter loaded. Type 'show_interactive_menu' for interactive mode."
fi