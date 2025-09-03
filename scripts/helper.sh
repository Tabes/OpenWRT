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

### Load Configuration and Dependencies ###
load_config() {
   ### Determine Project root dynamically ###
   local script_path="$(realpath "${BASH_SOURCE[0]}")"
   local script_dir="$(dirname "$script_path")"
   local project_root="$(dirname "$script_dir")"
   
   ### Look for project.conf in standard Locations ###
   local config_file=""
   if [ -f "$project_root/configs/project.conf" ]; then
       config_file="$project_root/configs/project.conf"
   elif [ -f "$project_root/project.conf" ]; then
       config_file="$project_root/project.conf"
   else
       print --error "Project configuration not found"
       return 1
   fi
   
   ### Source main configuration if found ###
   if [ -f "$config_file" ]; then
       source "$config_file"
   fi
   
   ### Load additional configuration files from configs/ ###
   if [ -d "$project_root/configs" ]; then
       for conf in "$project_root/configs"/*.conf; do
           ### Skip files starting with underscore and project.conf (already loaded) ###
           local basename=$(basename "$conf")
           if [[ ! "$basename" =~ ^_ ]] && [ "$conf" != "$config_file" ] && [ -f "$conf" ]; then
               source "$conf"
           fi
       done
   fi
   
   ### Load helper scripts from scripts/helper/ ###
   if [ -d "$project_root/scripts/helper" ]; then
       for script in "$project_root/scripts/helper"/*.sh; do
           ### Skip files starting with underscore ###
           local basename=$(basename "$script")
           if [[ ! "$basename" =~ ^_ ]] && [ -f "$script" ]; then
               source "$script"
           fi
       done
   fi
   
   ### Load additional scripts from scripts/ ###
   if [ -d "$project_root/scripts" ]; then
       for script in "$project_root/scripts"/*.sh; do
           ### Skip files starting with underscore and helper.sh (avoid self-sourcing) ###
           local basename=$(basename "$script")
           if [[ ! "$basename" =~ ^_ ]] && [ "$script" != "$script_path" ] && [ -f "$script" ]; then
               source "$script"
           fi
       done
   fi
   
   return 0
}


################################################################################
### === GLOBAL VARIABLES === ###
################################################################################

### Color definitions - can be overridden in project.conf ###
readonly NC="${COLOR_NC:-\033[0m}"
readonly RD="${COLOR_RD:-\033[0;31m}"
readonly GN="${COLOR_GN:-\033[0;32m}"
readonly YE="${COLOR_YE:-\033[1;33m}"
readonly BU="${COLOR_BU:-\033[0;34m}"
readonly CY="${COLOR_CY:-\033[0;36m}"
readonly WH="${COLOR_WH:-\033[1;37m}"
readonly MG="${COLOR_MG:-\033[0;35m}"

### Unicode symbols - can be overridden in project.conf ###
readonly SYMBOL_SUCCESS="${SYMBOL_SUCCESS:-✓}"
readonly SYMBOL_ERROR="${SYMBOL_ERROR:-✗}"
readonly SYMBOL_WARNING="${SYMBOL_WARNING:-⚠}"
readonly SYMBOL_INFO="${SYMBOL_INFO:-ℹ}"


################################################################################
### === STATUS & NOTIFICATION FUNCTIONS, LOGGING === ###
################################################################################

### Unified print Function for all Output Operations ###
print() {
   ### Local variables ###
   local output_buffer=""
   local current_color="${NC}"
   local current_alignment="left"
   local current_position=""
   local newlines=0
   local help_requested=false
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_apply_formatting() {
       local text="$1"
       local pos="$2"
       local align="$3"
       
       ### Calculate position based on alignment ###
       if [ "$align" = "right" ] && [ -n "$pos" ]; then
           ### Right align: position is where the last character should be ###
           local text_len=${#text}
           local start_pos=$((pos - text_len + 1))
           [ $start_pos -lt 1 ] && start_pos=1
           printf "\033[${start_pos}G%s" "$text"
       elif [ "$align" = "left" ] && [ -n "$pos" ]; then
           ### Left align: position is where the first character should be ###
           printf "\033[${pos}G%s" "$text"
       else
           ### No positioning, just print ###
           printf "%s" "$text"
       fi
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _print_help() {
       ### Try to load help from markdown file ###
       local help_file="${DOCS_DIR}/help/print.md"
       
        if [ -f "$help_file" ]; then
            ### Parse markdown and display formatted ###
            while IFS= read -r line; do
                case "$line" in
                    "# "*)
                        echo -e "${BU}${line#\# }${NC}"
                        ;;
                    "## "*)
                        echo -e "${CY}${line#\#\# }${NC}"
                        ;;
                    "### "*)
                        echo -e "${GN}${line#\#\#\# }${NC}"
                        ;;
                    "- "*)
                        echo "  ${line}"
                        ;;
                    "\`"*"\`"*)
                        echo -e "${YE}${line}${NC}"
                        ;;
                    "")
                        echo
                        ;;
                    *)
                        echo "$line"
                        ;;
                esac
            done < "$help_file"
        else
           ### Fallback to inline help ###
           printf "Usage: print [OPTIONS] [TEXT]...\n\n"
           printf "Options:\n"
           printf "\033[3G%-15s\033[20G%s\n" "COLOR" "Set color (NC, RD, GN, YE, BU, CY, WH, MG)"
           printf "\033[3G%-15s\033[20G%s\n" "-r POS" "Right align at position"
           printf "\033[3G%-15s\033[20G%s\n" "-l POS" "Left align at position"
           printf "\033[3G%-15s\033[20G%s\n" "--cr [N]" "Print N newlines (default: 1)"
           printf "\033[3G%-15s\033[20G%s\n" "--help, -h" "Show this help"
           printf "\nSpecial operations:\n"
           printf "\033[3G%-20s\033[25G%s\n" "--success MESSAGE" "Print success message"
           printf "\033[3G%-20s\033[25G%s\n" "--error MESSAGE" "Print error message"
           printf "\033[3G%-20s\033[25G%s\n" "--warning MESSAGE" "Print warning message"
           printf "\033[3G%-20s\033[25G%s\n" "--info MESSAGE" "Print info message"
           printf "\033[3G%-20s\033[25G%s\n" "--header TITLE" "Print header"
           printf "\033[3G%-20s\033[25G%s\n" "--line [CHAR]" "Print line"
        fi
    }
   
   ### Parse and execute arguments sequentially ###
   while [[ $# -gt 0 ]]; do
       case $1 in
           ### Special operations ###
           --success)
               printf "${GN}${SYMBOL_SUCCESS} $2${NC}\n"
               shift 2
               ;;
           --error)
               printf "${RD}${SYMBOL_ERROR} $2${NC}\n" >&2
               shift 2
               ;;
           --warning)
               printf "${YE}${SYMBOL_WARNING} $2${NC}\n"
               shift 2
               ;;
           --info)
               printf "${CY}${SYMBOL_INFO} $2${NC}\n"
               shift 2
               ;;
           --header)
               local line=$(printf "%80s" | tr ' ' '#')
               printf "${BU}${line}\n### $2\n${line}${NC}\n"
               shift 2
               ;;
           --line)
               local char="${2:-#}"
               local line=$(printf "%80s" | tr ' ' "$char")
               printf "${line}\n"
               shift 2
               ;;
           ### Formatting options ###
           --right|-r)
               current_alignment="right"
               current_position="$2"
               shift 2
               ;;
           --left|-l)
               current_alignment="left"
               current_position="$2"
               shift 2
               ;;
           --cr|-cr)
               if [[ "${2}" =~ ^[0-9]+$ ]]; then
                   newlines="$2"
                   shift 2
               else
                   newlines=1
                   shift
               fi
               for ((i=0; i<newlines; i++)); do
                   printf "\n"
               done
               newlines=0
               ;;
           ### Help ###
           --help|-h)
               _print_help
               return 0
               ;;
           ### Color detection ###
           NC|RD|GN|YE|BU|CY|WH|MG)
               current_color="${!1}"
               shift
               ;;
           ### Regular text ###
           *)
               ### Apply color and formatting ###
               printf "${current_color}"
               _print_apply_formatting "$1" "$current_position" "$current_alignment"
               printf "${NC}"
               shift
               ;;
       esac
   done
}

### Unified log Function for all Logging Operations ###
log() {
   ### Local variables ###
   local operation=""
   local message=""
   local script_name="${SCRIPT_NAME:-${0##*/}}"
   local log_file="${LOG_FILE:-${LOG_DIR:-/tmp}/${script_name%.sh}.log}"
   local log_level="${LOG_LEVEL:-INFO}"
   local timestamp=""
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _log_write() {
       local level="$1"
       local msg="$2"
       local file="${3:-$log_file}"
       
       ### Create log directory if needed ###
       local log_dir=$(dirname "$file")
       [ ! -d "$log_dir" ] && mkdir -p "$log_dir"
       
       ### Generate timestamp ###
       timestamp=$(date '+%Y-%m-%d %H:%M:%S')
       
       ### Write to script-specific log file ###
       echo "[$timestamp] [$level] $msg" >> "$file"
       
       ### Also write to central log if configured ###
       if [ -n "$CENTRAL_LOG" ] && [ "$CENTRAL_LOG" != "$file" ]; then
           echo "[$timestamp] [${script_name}] [$level] $msg" >> "$CENTRAL_LOG"
       fi
       
       ### Console output based on level ###
       case "$level" in
           ERROR)
               [ "${VERBOSE:-false}" = "true" ] && print --error "$msg"
               ;;
           WARNING)
               [ "${VERBOSE:-false}" = "true" ] && print --warning "$msg"
               ;;
           INFO)
               [ "${VERBOSE:-false}" = "true" ] && print --info "$msg"
               ;;
           DEBUG)
               [ "${DEBUG:-false}" = "true" ] && print CY "[DEBUG] $msg"
               ;;
       esac
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _log_init() {
       local file="${1:-$log_file}"
       local level="${2:-INFO}"
       
       ### Set global variables ###
       export LOG_FILE="$file"
       export LOG_LEVEL="$level"
       
       ### Create log directory ###
       local log_dir=$(dirname "$file")
       [ ! -d "$log_dir" ] && mkdir -p "$log_dir"
       
       ### Initialize log file with header ###
       {
           echo "################################################################################"
           echo "### Log Started: $(date '+%Y-%m-%d %H:%M:%S')"
           echo "### Script: ${script_name}"
           echo "### PID: $$"
           echo "### User: $(whoami)"
           echo "### Host: $(hostname)"
           echo "### Working Dir: $(pwd)"
           echo "################################################################################"
       } > "$file"
       
       _log_write "INFO" "Logging initialized - File: $file, Level: $level"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _log_rotate() {
       local file="${1:-$log_file}"
       local max_size="${2:-10485760}"  # 10MB default
       local max_files="${3:-5}"
       
       ### Check if file exists ###
       [ ! -f "$file" ] && return 0
       
       ### Get file size (cross-platform) ###
       local size=0
       if command -v stat >/dev/null 2>&1; then
           ### Try GNU stat first, then BSD stat ###
           size=$(stat --format=%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
       fi
       
       ### Rotate if size exceeds limit ###
       if [ "$size" -gt "$max_size" ]; then
           ### Rotate existing logs ###
           for ((i=$((max_files-1)); i>=1; i--)); do
               [ -f "${file}.$i" ] && mv "${file}.$i" "${file}.$((i+1))"
           done
           
           ### Move current log ###
           mv "$file" "${file}.1"
           
           ### Create new log ###
           _log_init "$file" "$LOG_LEVEL"
           _log_write "INFO" "Log rotated - Previous log: ${file}.1 (Size: $size bytes)"
       fi
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _log_tail() {
       local file="${1:-$log_file}"
       local lines="${2:-20}"
       
       if [ -f "$file" ]; then
           print --header "Last $lines log entries from $(basename "$file")"
           tail -n "$lines" "$file" | while IFS= read -r line; do
               case "$line" in
                   *"[ERROR]"*)
                       print RD "$line"
                       ;;
                   *"[WARNING]"*)
                       print YE "$line"
                       ;;
                   *"[INFO]"*)
                       print CY "$line"
                       ;;
                   *"[DEBUG]"*)
                       print MG "$line"
                       ;;
                   *"###"*)
                       print BU "$line"
                       ;;
                   *)
                       print "$line"
                       ;;
               esac
           done
       else
           print --error "Log file not found: $file"
       fi
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _log_search() {
       local pattern="$1"
       local file="${2:-$log_file}"
       
       if [ -f "$file" ]; then
           print --header "Searching for '$pattern' in $(basename "$file")"
           grep -n "$pattern" "$file" | while IFS= read -r line; do
               case "$line" in
                   *"[ERROR]"*)
                       print RD "$line"
                       ;;
                   *"[WARNING]"*)
                       print YE "$line"
                       ;;
                   *)
                       print CY "$line"
                       ;;
               esac
           done
       else
           print --error "Log file not found: $file"
       fi
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _log_help() {
       ### Try to load help from markdown file ###
       local help_file="${DOCS_DIR}/help/log.md"
       
       if [ -f "$help_file" ]; then
           ### Parse markdown and display formatted ###
           while IFS= read -r line; do
               case "$line" in
                   "# "*)
                       printf "${BU}${line#\# }${NC}\n"
                       ;;
                   "## "*)
                       printf "${CY}${line#\#\# }${NC}\n"
                       ;;
                   "### "*)
                       printf "${GN}${line#\#\#\# }${NC}\n"
                       ;;
                   "- "*)
                       printf "  ${line}\n"
                       ;;
                   "\`"*"\`"*)
                       printf "${YE}${line}${NC}\n"
                       ;;
                   "")
                       printf "\n"
                       ;;
                   *)
                       printf "${line}\n"
                       ;;
               esac
           done < "$help_file"
       else
           ### Fallback to inline help ###
           local P1="${POS[0]:-4}"   # Position 4
           local P2="${POS[3]:-35}"  # Position 35
           
           print "Usage: log [OPERATION] [OPTIONS]"
           print --cr
           print "Operations:"
           print -l "$P1" "--init [FILE] [LEVEL]" -l "$P2" "Initialize logging"
           print -l "$P1" "--info MESSAGE" -l "$P2" "Log info message"
           print -l "$P1" "--error MESSAGE" -l "$P2" "Log error message"
           print -l "$P1" "--warning MESSAGE" -l "$P2" "Log warning message"
           print -l "$P1" "--debug MESSAGE" -l "$P2" "Log debug message"
           print -l "$P1" "--rotate [FILE] [SIZE] [COUNT]" -l "$P2" "Rotate log files"
           print -l "$P1" "--tail [FILE] [LINES]" -l "$P2" "Show last log entries"
           print -l "$P1" "--search PATTERN [FILE]" -l "$P2" "Search in log file"
           print -l "$P1" "--clear [FILE]" -l "$P2" "Clear log file"
           print -l "$P1" "--help, -h" -l "$P2" "Show this help"
           print --cr
           print "Log Levels: DEBUG, INFO, WARNING, ERROR"
           print "Default log: ${LOG_DIR:-/tmp}/SCRIPTNAME.log"
       fi
   }
   
   ### Parse arguments ###
   while [[ $# -gt 0 ]]; do
       case $1 in
           --init)
               _log_init "${2:-$log_file}" "${3:-INFO}"
               [ $# -ge 3 ] && shift 3 || shift $#
               ;;
           --info)
               _log_write "INFO" "$2"
               shift 2
               ;;
           --error)
               _log_write "ERROR" "$2"
               shift 2
               ;;
           --warning)
               _log_write "WARNING" "$2"
               shift 2
               ;;
           --debug)
               _log_write "DEBUG" "$2"
               shift 2
               ;;
           --rotate)
               _log_rotate "${2:-$log_file}" "${3:-10485760}" "${4:-5}"
               shift $#
               ;;
           --tail)
               _log_tail "${2:-$log_file}" "${3:-20}"
               shift $#
               ;;
           --search)
               _log_search "$2" "${3:-$log_file}"
               shift $#
               ;;
           --clear)
               local file="${2:-$log_file}"
               > "$file"
               _log_write "INFO" "Log file cleared by user"
               shift $#
               ;;
           --help|-h)
               _log_help
               return 0
               ;;
           *)
               print --error "Unknown log operation: $1"
               _log_help
               return 1
               ;;
       esac
   done
}


################################################################################
### === INTERACTIVE DISPLAY FUNCTIONS === ###
################################################################################

### Unified show function for interactive displays and menus ###
show() {
   ### Local variables ###
   local operation=""
   local title=""
   local content=""
   local options=()
   local selected=0
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _show_menu() {
       local menu_title="$1"
       shift
       local menu_options=("$@")
       local choice
       
       ### Display menu ###
       print --header "$menu_title"
       print --cr
       
       ### Display options ###
       local i=1
       for option in "${menu_options[@]}"; do
           print -l 3 "[$i]" -l 8 "$option"
           ((i++))
       done
       print -l 3 "[0]" -l 8 "Exit"
       print --cr
       
       ### Get user choice ###
       read -p "Please select [0-$((i-1))]: " choice
       echo "$choice"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _show_spinner() {
       local pid="$1"
       local delay="${2:-0.1}"
       local spinstr='|/-\'
       
       while kill -0 "$pid" 2>/dev/null; do
           local temp=${spinstr#?}
           printf " [%c]  " "$spinstr"
           local spinstr=$temp${spinstr%"$temp"}
           sleep $delay
           printf "\b\b\b\b\b\b"
       done
       printf "    \b\b\b\b"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _show_progress() {
       local current="$1"
       local total="$2"
       local description="${3:-Progress}"
       local width="${4:-50}"
       
       local percent=$((current * 100 / total))
       local filled=$((width * current / total))
       
       printf "\r["
       printf "%${filled}s" | tr ' ' '='
       printf "%$((width - filled))s" | tr ' ' '-'
       printf "] %3d%% %s" "$percent" "$description"
       
       [ "$current" -eq "$total" ] && echo
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _show_help() {
       ### Try to load help from markdown file ###
       local help_file="${DOCS_DIR}/help/show.md"
       
        if [ -f "$help_file" ]; then
            ### Parse markdown and display formatted ###
            while IFS= read -r line; do
                case "$line" in
                    "# "*)
                        printf "${BU}${line#\# }${NC}\n"
                        ;;
                    "## "*)
                        printf "${CY}${line#\#\# }${NC}\n"
                        ;;
                    "### "*)
                        printf "${GN}${line#\#\#\# }${NC}\n"
                        ;;
                    "- "*)
                        printf "  ${line}\n"
                        ;;
                    "\`"*"\`"*)
                        printf "${YE}${line}${NC}\n"
                        ;;
                    "")
                        printf "\n"
                        ;;
                    *)
                        printf "${line}\n"
                        ;;
                esac
            done < "$help_file"
        else
            ### Fallback to inline help ###
            local P1="${POS[0]}"  # Position 4
            local P2="${POS[2]}"  # Position 21
            local P3="${POS[3]}"  # Position 35
            
            print "Usage: show [OPERATION] [OPTIONS]"
            print --cr
            print "Operations:"
            print -l "$P1" "--menu TITLE OPTS..." -l "$P3" "Display interactive menu"
            print -l "$P1" "--spinner PID [DELAY]" -l "$P3" "Show progress spinner"
            print -l "$P1" "--progress CUR TOTAL" -l "$P3" "Show progress bar"
            print -l "$P1" "--version" -l "$P3" "Show version information"
            print -l "$P1" "--doc FILE" -l "$P3" "Display documentation file"
            print -l "$P1" "--help, -h" -l "$P3" "Show this help"
        fi
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _show_version() {
       print --header "Universal Helper Functions"
       print -l 3 "Version:" -l 20 "$SCRIPT_VERSION"
       print -l 3 "Commit:" -l 20 "$COMMIT"
       print -l 3 "Author:" -l 20 "Mawage (Development Team)"
       print -l 3 "License:" -l 20 "MIT"
   }
   
   # shellcheck disable=SC2317,SC2329  # Function called conditionally within main function
   _show_doc() {
       local doc_file="$1"
       
       ### Check if path is relative or absolute ###
       if [[ ! "$doc_file" =~ ^/ ]]; then
           doc_file="${DOCS_DIR}/${doc_file}"
       fi
       
       if [ -f "$doc_file" ]; then
           ### Display file with formatting ###
           while IFS= read -r line; do
               case "$line" in
                   "# "*)
                       print --header "${line#\# }"
                       ;;
                   "## "*)
                       print CY "${line#\#\# }"
                       print --line "-"
                       ;;
                   "### "*)
                       print GN "${line#\#\#\# }"
                       ;;
                   "- "*)
                       print -l 3 "•" -l 6 "${line#- }"
                       ;;
                   "\`\`\`"*)
                       ### Code block start/end ###
                       print YE "$line"
                       ;;
                   "")
                       print --cr
                       ;;
                   *)
                       print "$line"
                       ;;
               esac
           done < "$doc_file"
       else
           print --error "Documentation file not found: $doc_file"
       fi
   }
   
   ### Parse arguments ###
   while [[ $# -gt 0 ]]; do
       case $1 in
           --menu)
               shift
               title="$1"
               shift
               while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                   options+=("$1")
                   shift
               done
               _show_menu "$title" "${options[@]}"
               return $?
               ;;
           --spinner)
               _show_spinner "$2" "${3:-0.1}"
               shift 3
               ;;
           --progress)
               _show_progress "$2" "$3" "${4:-Progress}" "${5:-50}"
               shift 5
               ;;
           --version)
               _show_version
               shift
               ;;
           --doc)
               _show_doc "$2"
               shift 2
               ;;
           --help|-h)
               _show_help
               return 0
               ;;
           *)
               print --error "Unknown show operation: $1"
               _show_help
               return 1
               ;;
       esac
   done
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
    log --init "${LOG_DIR}/${PROJECT_NAME}.log" "${LOG_LEVEL_INFO}"
    
    ### Log startup ###
    log --info "Helper Functions startup: $*"
    
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
    log --info "Helper Functions cleanup"
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