#!/bin/bash
################################################################################
### Project Fixing Manager - Universal fixing Project File Management
### Convert Windows CRLF to Unix LF and set correct Unix Permissions
################################################################################
### Project: Universal Fixing Manager
### Version: 1.0.0
### Author:  Mawage (Workflow Team)
### Date:    2025-08-20
### License: MIT
### Usage:   ./fix-project.sh [--help]
################################################################################

SCRIPT_VERSION="1.0.0"
COMMIT="Convert Windows CRLF to Unix LF, set correct Unix Permissions"

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
### === MENU AND HELP === ###
################################################################################

### Workflow Menu ###
show_menu() {
    print_header "Enter Header Informations here."
    
    
    echo "📌 COMMAND LINE OPTIONS:"


    echo "EXAMPLES:"
}


################################################################################
### === MAIN EXECUTION === ###
################################################################################

### Parse Command Line Arguments ###
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_menu
                exit 0
                ;;

        esac
        shift
    done
}

### Main function ###
main() {
    load_config
    
    if [ $# -eq 0 ]; then
        show_menu
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo "Try '$0 --help' for more Information"
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
    print_success "Fix Project Manager loaded. Type 'show_menu' for help."
fi