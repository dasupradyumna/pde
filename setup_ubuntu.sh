#!/bin/bash
########################################### UBUNTU SETUP ###########################################
# TEST: sudo ./setup_ubuntu.sh behavior

# Source all setup modules
for module in setup/*.sh; do source "$module"; done

# Global variables
LOCAL_DIR="$HOME/.local"
CONFIG_DIR="$HOME/.config"
SUDO="$([ $(id -u) -ne 0 ] && printf sudo || echo -n)"
TEMP_DIR="$PWD/tmp"
FIFO_FILE="/tmp/tmp.pde_fifo"
FREE_VERSIONS_FILE="$PWD/free.version"
LOCK_VERSIONS_FILE="$PWD/lock.version"
declare -A FREE_VERSIONS=() LOCK_VERSIONS=()

# Command-line options
OPT__HEADLESS=false
OPT__SYSTEM_SCOPE=false
OPT__UNINSTALL=false

# Show help message and exit the script, with optional exit code
show_help() {
    echo '
Usage: ./setup_ubuntu.sh [-hsU]
    -h : Show this help message
    -H : Headless installation
    -s : System scope (/usr/local); if not set, fallback to user scope (~/.local)
    -U : Uninstall programs and configs
'
    exit $1
}

# Parse command-line options
parse_opts() {
    # Modify variables based on options
    OPTIND=1; while getopts ':hHsU' option; do
        case "$option" in
            h) show_help 0 ;;
            H) OPT__HEADLESS=true ;;
            s) OPT__SYSTEM_SCOPE=true; LOCAL_DIR=/usr/local ;;
            U) OPT__UNINSTALL=true ;;
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
    - Headless Install: $OPT__HEADLESS
    - System Scope: $OPT__SYSTEM_SCOPE
    - Uninstall: $OPT__UNINSTALL"
}

# Handle SIGINT - exit with code 130 = 128 + 2 (SIGINT)
interrupt_handler() { tput ed; log -e "[SIGINT] User aborted the script!"; exit 130; }

# Handle SIGEXIT - clean up and propagate exit code
exit_handler() {
    code=$?
    if [ $code -eq 0 ]; then
        rm -f "$FREE_VERSIONS_FILE.bak"
    elif [ -f "$FREE_VERSIONS_FILE.bak" ]; then
        mv -f "$FREE_VERSIONS_FILE.bak" "$FREE_VERSIONS_FILE"
    fi
    rm -rf "$TEMP_DIR" "$FIFO_FILE"
    tput cnorm
    exit $code
}

main() {
    set -e
    trap interrupt_handler INT
    trap exit_handler EXIT
    tput civis
    $OPT__UNINSTALL || mkdir -p "$TEMP_DIR" "$LOCAL_DIR/bin" "$CONFIG_DIR"

    parse_opts $@

    load_tool_versions
    ensure_system_deps
    manage_git
    manage_wezterm
    manage_ai_agents
    manage_neovim

    manage_configs
}

main $@
