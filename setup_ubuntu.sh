#!/bin/bash
########################################### UBUNTU SETUP ###########################################
# Setup all programs required for the PDE in Ubuntu and install their configs appropriately

# Source all setup modules
for module in setup/*.sh; do source "$module"; done

INSTALL_DIR="$HOME/.local"
SUDO="$([ $(id -u) -ne 0 ] && printf sudo || echo -n)"
TEMP_DIR="$PWD/tmp"
declare -A TOOL_VERSIONS=()

OPT__SYSTEM_TARGET=false
OPT__UNINSTALL=false

# Show help message and exit the script, with optional exit code
show_help() {
    echo '
Usage: ./setup_ubuntu.sh [-hsU]
    -h : Show this help message
    -s : System scope (/usr/local); if not set, fallback to user scope (~/.local)
    -U : Uninstall programs and configs
'
    exit $1
}

# Parse command-line options
parse_opts() {
    # Modify variables based on options
    OPTIND=1; while getopts ':hsU' option; do
        case "$option" in
            h) show_help 0 ;;
            s) OPT__SYSTEM_TARGET=true; INSTALL_DIR=/usr/local ;;
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
    - System Scope: $OPT__SYSTEM_TARGET
    - Uninstall: $OPT__UNINSTALL"
}

# Load tool versions from version.lock file
load_version_lock() {
    if $OPT__UNINSTALL; then return; fi

    while read -r tool version; do
        if [ -z "$tool" ] || [ -z "$version" ] || [ "${tool:0:1}" == '#' ]; then continue; fi

        TOOL_VERSIONS["$tool"]="$version"
    done < "$PWD/version.lock"

    log -i 'Loaded tool versions from version.lock'
}

# Check if dependencies are already up-to-date, and install them if otherwise
ensure_dependencies() {
    if $OPT__UNINSTALL; then return; fi

    local -ra DEPS=('bash-completion' 'build-essential' 'curl' 'software-properties-common')
    echo && log -i 'Ensuring common dependencies are installed ...'

    # Check if dependencies are already up-to-date
    local installed latest skip_install=true
    for dep in "${DEPS[@]}"; do
        read -r installed latest < <(apt_pkg_versions "$dep")
        if ! is_latest_installed "$dep" "$installed" "$latest"; then skip_install=false; fi
    done

    # Skip installation if dependencies are already up-to-date
    if $skip_install; then log -i 'All common dependencies already up-to-date'; return; fi

    # Install dependencies
    exec_ring_log $SUDO apt-get update
    exec_ring_log $SUDO apt-get install -y bash-completion build-essential curl \
        software-properties-common
    log -i 'Installed common dependencies'
}

# Copy tool configs to their appropriate locations
# TODO: Support global configs as well, when OPT__SYSTEM_TARGET is true
# CHECK: If paths in git config are valid for system install
copy_configs() {
    local -a tools=(delta git lazygit)

    if $OPT__UNINSTALL; then
        echo && log -i 'Uninstalling configs ...'
    else
        echo && log -i 'Installing configs ...'
        mkdir -p "$HOME/.config"
    fi

    for tool in "${tools[@]}"; do
        if $OPT__UNINSTALL; then
            rm -rf "$HOME/.config/$tool"
            log -i "Removed: $HOME/.config/$tool"
        else
            ln -sfT "$PWD/config/$tool" "$HOME/.config/$tool"
            log -i "Linked: $PWD/config/$tool -> $HOME/.config/$tool"
        fi
    done
}

main() {
    set -e
    trap interrupt_handler INT
    trap exit_handler EXIT
    tput civis
    mkdir "$TEMP_DIR"

    parse_opts $@
    load_version_lock

    ensure_dependencies
    setup_git

    copy_configs

    # NOTE: this should be part of the bash environment ; ensures 256 color support
    #       Only add an export if the variable is not already set
    echo 'export TERM=xterm-256color COLORTERM=truecolor' >> "$HOME/.bashrc"
}

main $@
