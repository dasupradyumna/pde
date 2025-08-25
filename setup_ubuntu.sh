#!/bin/bash
########################################### UBUNTU SETUP ###########################################
# Setup all programs required for the PDE in Ubuntu and install their configs appropriately

# Source all setup modules
for module in setup/*.sh; do source "$module"; done

# UBUNTU_ver="$(source /etc/os-release && echo $ver_ID)"
INSTALL_DIR="$HOME/.local"
SUDO="$([ $(id -u) -ne 0 ] && printf sudo || echo -n)"
TEMP_DIR="$PWD/tmp"

OPT__SYSTEM_INSTALL=false

# Show help message and exit the script, with optional exit code
show_help() {
    echo '
Usage: ./setup_ubuntu.sh [-hs]
    -h : Show this help message
    -s : System install (/usr/local); if not set, fallback to user install (~/.local)
'
    exit $1
}

# Parse command-line options
parse_opts() {
    # Modify variables based on options
    OPTIND=1; while getopts ':hs' option; do
        case "$option" in
            h) show_help 0 ;;
            s) OPT__SYSTEM_INSTALL=true; INSTALL_DIR=/usr/local ;;
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
    - System Install: $OPT__SYSTEM_INSTALL"
}

# Check if dependencies are already up-to-date, and install them if otherwise
ensure_dependencies() {
    local -ra DEPS=('bash-completion' 'build-essential' 'curl' 'software-properties-common')
    echo && log -i 'Ensuring common dependencies are installed ...'

    # Check if dependencies are already up-to-date
    local installed latest skip_install=true
    for dep in "${DEPS[@]}"; do
        read -r installed latest < <(apt_pkg_versions "$dep")
        if [ "$installed" = "$latest" ]; then
            log -i "Checking '$dep': Already latest - $installed"
        else
            log -w "Checking '$dep': Installed $installed >> Latest $latest"
            skip_install=false
        fi
    done

    # Skip installation if dependencies are already up-to-date
    if $skip_install; then log -i 'All common dependencies already up-to-date'; return; fi

    # Install dependencies
    exec_ring_log $SUDO apt-get update
    exec_ring_log $SUDO apt-get install -y bash-completion build-essential curl \
        software-properties-common
    log -i 'Installed common dependencies'
}

main() {
    set -e
    trap interrupt_handler INT
    trap exit_handler EXIT
    tput civis
    mkdir "$TEMP_DIR"

    parse_opts $@

    ensure_dependencies
    setup_git
}

main $@
