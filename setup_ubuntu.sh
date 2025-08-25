#!/bin/bash
########################################### UBUNTU SETUP ###########################################
# Setup all programs required for the PDE in Ubuntu and install their configs appropriately

# Source all setup modules
for module in setup/*.sh; do source "$module"; done

# UBUNTU_ver="$(source /etc/os-release && echo $ver_ID)"
TMPDIR="$PWD/tmp"

install_deps() {
    apt-get update
    apt-get install -y bash-completion build-essential curl software-properties-common
}

main() {
    set -e
    trap interrupt_handler INT
    trap exit_handler EXIT
    tput civis
    mkdir -p "$TMPDIR"

    # Common Dependencies
    echo && log -i 'Installing common dependencies ...'
    exec_ring_log install_deps
    log -i 'Completed'

    setup_git
}

main $@
