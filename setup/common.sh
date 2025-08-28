######################################## COMMON SETUP LOGIC ########################################

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

declare -r BASHRC_ENTRYPOINT="
# >>> PDE-ENTRYPOINT >>>
source $PWD/config/bash/init.sh
# <<< PDE-ENTRYPOINT <<<"

# Manage tool configs - install or uninstall based on flags
# TODO: Support global configs as well, when OPT__SYSTEM_SCOPE is true
# CHECK: If paths in git config are valid for system install
manage_configs() {
    if $OPT__UNINSTALL; then
        echo && log -i 'Uninstalling configs ...'
    else
        echo && log -i 'Installing configs ...'
        mkdir -p "$HOME/.config"
    fi

    # Manage tool config symlinks
    local -a tools=(delta git lazygit)
    for tool in "${tools[@]}"; do
        if $OPT__UNINSTALL; then
            rm -rf "$HOME/.config/$tool"
            log -i "Removed: $HOME/.config/$tool"
        else
            ln -sfT "$PWD/config/$tool" "$HOME/.config/$tool"
            log -i "Linked: $PWD/config/$tool -> $HOME/.config/$tool"
        fi
    done

    # Manage bash entry point
    if $OPT__UNINSTALL; then
        sed -i '/^# >>> PDE-ENTRYPOINT >>>$/,/^# <<< PDE-ENTRYPOINT <<<$/d' "$HOME/.bashrc"
        sed -i '/^$/N;/^\n$/D' "$HOME/.bashrc" # Squash consecutive empty lines
        sed -i '${/^$/d}' "$HOME/.bashrc" # Delete last line if empty
        log -i 'Removed PDE bash entry point from .bashrc'
    elif ! grep -q ">>> PDE-ENTRYPOINT >>>" "$HOME/.bashrc"; then
        echo "$BASHRC_ENTRYPOINT" >> "$HOME/.bashrc"
        log -i 'Added PDE bash entry point to ~/.bashrc'
    fi
}
