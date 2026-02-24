######################################## COMMON SETUP LOGIC ########################################

# Read tool names and their version from a file
#
# Usage: __read_versions_file <file> <dict>
__read_versions_file() {
    local -r file="$1" dict="$2"
    while read -r tool version; do
        if [ -z "$tool" ] || [ -z "$version" ] || [ "${tool:0:1}" == '#' ]; then continue; fi
        eval "$dict[$tool]=$version"
    done < "$file"
}

# Load tool versions - locked and/or free
load_tool_versions() {
    if $OPT__UNINSTALL; then return; fi

    __read_versions_file "$LOCK_VERSIONS_FILE" LOCK_VERSIONS
    log -i "Loaded locked versions from '$(basename "$LOCK_VERSIONS_FILE")'"

    if [ -f "$FREE_VERSIONS_FILE" ]; then
        __read_versions_file "$FREE_VERSIONS_FILE" FREE_VERSIONS
        # Back-up existing free versions file
        cp "$FREE_VERSIONS_FILE" "$FREE_VERSIONS_FILE.bak"
        log -i "Loaded free versions from '$(basename "$FREE_VERSIONS_FILE")'"
    fi
    echo -e "####################### FREE VERSIONS ######################\n" > "$FREE_VERSIONS_FILE"
}

# Check if dependencies are already up-to-date, and install them if otherwise
ensure_system_deps() {
    if $OPT__UNINSTALL; then return; fi

    local -a deps=('bash-completion' 'build-essential' 'cmake' 'curl' 'software-properties-common')
    $OPT__HEADLESS || deps+=('python3-nautilus')
    echo && log -i 'Ensuring dependencies are installed ...'

    # Check if dependencies are already up-to-date
    local installed latest skip_install=true
    for dep in "${deps[@]}"; do
        read -r installed latest < <(apt_pkg_versions "$dep")
        installed="${FREE_VERSIONS[$dep]:-(none)}"
        echo "$dep    $latest" >> "$FREE_VERSIONS_FILE"
        if ! is_latest_installed "$dep" "$installed" "$latest"; then skip_install=false; fi
    done

    # Skip installation if dependencies are already up-to-date
    if $skip_install; then log -i 'All system dependencies already up-to-date'; return; fi

    # Install dependencies
    exec_ring_log $SUDO apt-get update
    exec_ring_log $SUDO apt-get install -y ${deps[@]}
    log -i 'Installed system dependencies'
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
    fi

    # Manage tool config symlinks
    local -a tools=(aider delta gdb git lazygit nvim opencode)
    $OPT__HEADLESS || tools+=(wezterm)
    for tool in "${tools[@]}"; do
        if $OPT__UNINSTALL; then
            rm -rf "$CONFIG_DIR/$tool"
            log -i "Removed: $CONFIG_DIR/$tool"
        else
            ln -sfT "$PWD/config/$tool" "$CONFIG_DIR/$tool"
            log -i "Linked: $PWD/config/$tool -> $CONFIG_DIR/$tool"
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
