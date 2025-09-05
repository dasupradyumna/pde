#!/bin/bash
########################################### UBUNTU SETUP ###########################################

# Source all setup modules
for module in setup/*.sh; do source "$module"; done

# Global variables
INSTALL_DIR="$HOME/.local"
SUDO="$([ $(id -u) -ne 0 ] && printf sudo || echo -n)"
TEMP_DIR="$PWD/tmp"
declare -A TOOL_VERSIONS=()

# Command-line options
OPT__SYSTEM_SCOPE=false
OPT__UNINSTALL=false
OPT__SKIP_WEZTERM=false

# Show help message and exit the script, with optional exit code
show_help() {
    echo '
Usage: ./setup_ubuntu.sh [-hsU]
    -h : Show this help message
    -s : System scope (/usr/local); if not set, fallback to user scope (~/.local)
    -U : Uninstall programs and configs
    -W : Skip WezTerm
'
    exit $1
}

# Parse command-line options
parse_opts() {
    # Modify variables based on options
    OPTIND=1; while getopts ':hsUW' option; do
        case "$option" in
            h) show_help 0 ;;
            s) OPT__SYSTEM_SCOPE=true; INSTALL_DIR=/usr/local ;;
            U) OPT__UNINSTALL=true ;;
            W) OPT__SKIP_WEZTERM=true ;;
            \?) log -e "Invalid command-line option '-$OPTARG'!"; show_help 1 ;;
            :) log -e "Command-line option '-$OPTARG' requires an argument!"; show_help 1 ;;
        esac
    done
    unset -f abspath
    shift $((OPTIND - 1))

    # Raise error in case of any positional arguments
    if [ $# -ne 0 ]; then
        log -e "Positional arguments are not supported! Received: $(printf "'%s' " $@)"
        show_help 1
    fi

    log -i "Parsing command-line options ...
    - System Scope: $OPT__SYSTEM_SCOPE
    - Uninstall: $OPT__UNINSTALL
    - Skip WezTerm: $OPT__SKIP_WEZTERM"
}

# Handle SIGINT - exit with code 130 = 128 + 2 (SIGINT)
interrupt_handler() { log -e "[SIGINT] User aborted the script!"; exit 130; }

# Handle SIGEXIT - clean up and propagate exit code
exit_handler() { code=$?; tput cnorm; rm -rf "$TEMP_DIR"; exit $code; }

main() {
    set -e
    trap interrupt_handler INT
    trap exit_handler EXIT
    tput civis
    mkdir "$TEMP_DIR"

    parse_opts $@

    load_version_lock
    ensure_dependencies
    manage_git
    manage_wezterm

    manage_configs
}

main $@
