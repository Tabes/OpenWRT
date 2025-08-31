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

### Unified print function for all output operations ###
print() {
   ### Parse Arguments ###
   while [[ $# -gt 0 ]]; do
       case $1 in
           --success)
               _print_success "$2"
               shift 2
               ;;
           --error)
               _print_error "$2"
               shift 2
               ;;
           --warning)
               _print_warning "$2"
               shift 2
               ;;
           --info)
               _print_info "$2"
               shift 2
               ;;
           --header)
               _print_header "$2"
               shift 2
               ;;
           --line)
               _print_line "${2:-#}" "${3:-80}"
               shift 3
               ;;
           --help|-h)
               _print_help
               exit 0
               ;;
           *)
               shift
               ;;
       esac
   done
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_success() {
       echo -e "${GREEN}${SYMBOL_SUCCESS} $1${NC}"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_error() {
       echo -e "${RED}${SYMBOL_ERROR} $1${NC}" >&2
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_warning() {
       echo -e "${YELLOW}${SYMBOL_WARNING} $1${NC}"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_info() {
       echo -e "${CYAN}${SYMBOL_INFO} $1${NC}"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_header() {
       local title="$1"
       local line=$(printf "%80s" | tr ' ' '#')
       echo -e "${BLUE}${line}${NC}"
       echo -e "${BLUE}### ${title}${NC}"
       echo -e "${BLUE}${line}${NC}"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_line() {
       local char="$1"
       local width="$2"
       local line=$(printf "%${width}s" | tr ' ' "$char")
       echo "$line"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_help() {
       echo "Usage: print [OPTION] [MESSAGE]"
       echo "Options:"
       echo "  --success MESSAGE    Print success message"
       echo "  --error MESSAGE      Print error message"
       echo "  --warning MESSAGE    Print warning message"
       echo "  --info MESSAGE       Print info message"
       echo "  --header TITLE       Print header with title"
       echo "  --line [CHAR] [WIDTH] Print line"
       echo "  --help, -h           Show this help"
   }
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
   log --init "${LOG_DIR}/logfile.log" "${LOG_LEVEL_INFO}"
   
   ### Log startup ###
   log --info "Helper functions startup: $*"
   
   ### Check if no arguments provided ###
   if [ $# -eq 0 ]; then
       show --header "Universal Helper Functions v${SCRIPT_VERSION}"
       show --doc --help
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