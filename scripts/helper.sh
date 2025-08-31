#!/bin/bash
################################################################################
### Universal Helper Functions - Complete Utility Library
### Comprehensive Collection of Helper Functions for bash Scripts
### Provides Output, Logging, Validation, System, Network and Utility Functions
################################################################################
### Project: Universal Helper Library
### Version: 2.1.0
### Author:  Mawage (Development Team)
### Date:    2025-08-31
### License: MIT
### Usage:   Source this File to Load Helper Functions
################################################################################

SCRIPT_VERSION="1.0.0"
COMMIT="Initial helper functions library structure"


################################################################################
### === INITIALIZATION === ###
################################################################################

### Load configuration and dependencies ###
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
       echo "ERROR: Project configuration not found"
       return 1
   fi
   
   ### Source configuration if found ###
   if [ -f "$config_file" ]; then
       source "$config_file"
       return 0
   fi
   
   return 1
}


################################################################################
### === STATUS & NOTIFICATION FUNCTIONS === ###
################################################################################

### Unified Print function for all Output Oerations ###
print() {
    ### Local variables ###
    local message=""
    local color="${NC}"
    local symbol=""
    local position=""
    local alignment="left"
    local newlines=0
    local operation=""
    
    ### Parse Arguments ###
    while [[ $# -gt 0 ]]; do
        case $1 in
            --success)
                operation="success"
                color="${GREEN}"
                symbol="${SYMBOL_SUCCESS}"
                message="$2"
                shift 2
                ;;
            --error)
                operation="error"
                color="${RED}"
                symbol="${SYMBOL_ERROR}"
                message="$2"
                shift 2
                ;;
            --warning)
                operation="warning"
                color="${YELLOW}"
                symbol="${SYMBOL_WARNING}"
                message="$2"
                shift 2
                ;;
            --info)
                operation="info"
                color="${CYAN}"
                symbol="${SYMBOL_INFO}"
                message="$2"
                shift 2
                ;;
            --header)
                operation="header"
                message="$2"
                shift 2
                ;;
            --line)
                operation="line"
                message="${2:-#}"
                shift 2
                ;;
            --pos)
                position="$2"
                shift 2
                ;;
            --left|-l)
                alignment="left"
                shift
                ;;
            --right|-r)
                alignment="right"
                shift
                ;;
            --cr)
                if [[ "${2}" =~ ^[0-9]+$ ]]; then
                    newlines="$2"
                    shift 2
                else
                    newlines=1
                    shift
                fi
                ;;
            --help|-h)
                _print_help
                return 0
                ;;
            *)
                if [ -z "$message" ]; then
                    message="$1"
                fi
                shift
                ;;
        esac
    done
    
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _print_formatted() {
        local text="$1"
        local col_pos="${2:-1}"
        
        ### Handle positioning ###
        if [ -n "$position" ]; then
            if [[ "$position" =~ ^[0-9]+$ ]]; then
                col_pos="$position"
            fi
        fi
        
        ### Handle alignment ###
        if [ "$alignment" = "right" ]; then
            local term_width=$(tput cols)
            local text_len=${#text}
            col_pos=$((term_width - text_len))
        fi
        
        ### Move to position and print ###
        if [ "$col_pos" -gt 1 ]; then
            printf "%*s%s" $((col_pos - 1)) "" "$text"
        else
            printf "%s" "$text"
        fi
    }
    
    # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
    _print_help() {
        ### Try to load help from markdown file ###
        local help_file="${DOCS_DIR:-./docs/help}/print.md"
        
        if [ -f "$help_file" ]; then
            ### Parse markdown and display formatted ###
            while IFS= read -r line; do
                case "$line" in
                    "# "*)
                        ### Main header ###
                        echo -e "${BLUE}${line#\# }${NC}"
                        ;;
                    "## "*)
                        ### Sub header ###
                        echo -e "${CYAN}${line#\#\# }${NC}"
                        ;;
                    "### "*)
                        ### Section header ###
                        echo -e "${GREEN}${line#\#\#\# }${NC}"
                        ;;
                    "- "*)
                        ### List item ###
                        echo "  ${line}"
                        ;;
                    "\`"*"\`"*)
                        ### Code inline ###
                        echo -e "${YELLOW}${line}${NC}"
                        ;;
                    "")
                        ### Empty line ###
                        echo
                        ;;
                    *)
                        ### Regular text ###
                        echo "$line"
                        ;;
                esac
            done < "$help_file"
        else
            ### Fallback to inline help ###
            echo "Usage: print [OPTION] [MESSAGE]"
            echo "Options:"
            echo "  --success MESSAGE    Print success message"
            echo "  --error MESSAGE      Print error message"
            echo "  --warning MESSAGE    Print warning message"
            echo "  --info MESSAGE       Print info message"
            echo "  --header TITLE       Print header with title"
            echo "  --line [CHAR]        Print line with character"
            echo "  --pos COLUMN         Set column position"
            echo "  --left, -l           Left align (default)"
            echo "  --right, -r          Right align"
            echo "  --cr [N]             Print N newlines (default: 1)"
            echo "  --help, -h           Show this help"
        fi
    }
    
    ### Execute operation ###
    case "$operation" in
        success|error|warning|info)
            local output="${symbol} ${message}"
            echo -e "${color}$(_print_formatted "$output")${NC}"
            ;;
        header)
            local line=$(printf "%80s" | tr ' ' '#')
            echo -e "${BLUE}${line}${NC}"
            echo -e "${BLUE}### ${message}${NC}"
            echo -e "${BLUE}${line}${NC}"
            ;;
        line)
            local line=$(printf "%80s" | tr ' ' "$message")
            echo "$line"
            ;;
        *)
            ### Plain text output ###
            if [ -n "$message" ]; then
                echo -e "${color}$(_print_formatted "$message")${NC}"
            fi
            ;;
    esac
    
    ### Print newlines ###
    if [ "$newlines" -gt 0 ]; then
        for ((i=0; i<newlines; i++)); do
            echo
        done
    fi
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
               show --help
               exit 0
               ;;
           -V|--version)
               show --version
               exit 0
               ;;
           *)
               shift
               ;;
       esac
   done
}

### Main function ###
main() {
   ### Load configuration and dependencies ###
   load_config
   
   ### Initialize logging ###
   # log --init "${LOG_DIR}/logfile.log" "${LOG_LEVEL_INFO}"
   
   ### Log startup ###
   # log --info "Helper functions startup: $*"
   
   ### Check if no arguments provided ###
   if [ $# -eq 0 ]; then
       # show --header "Universal Helper Functions v${SCRIPT_VERSION}"
       # show --doc --help
       exit 0
   else
       ### Parse and execute arguments ###
       parse_arguments "$@"
   fi
}

### Cleanup function ###
cleanup() {
   log --info "Helper functions cleanup"
}

### Initialize when run directly ###
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
   ### Running directly ###
   main "$@"
else
   ### Being sourced ###
   load_config
   print --success "Helper functions loaded. Type 'show --menu' for an interactive menu."
fi