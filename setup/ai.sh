########################################## SETUP AI AGENTS #########################################

# Execute installation or uninstallation logic based on command-line options
manage_ai_agents() {
    if $OPT__UNINSTALL; then
        cd "$LOCAL_DIR/bin"
        $SUDO rm -rf 'aider' 'opencode'
        cd ~-
        # TODO: should ~/.opencode be removed as well?
        echo && log -i 'Uninstalled Aider and OpenCode'
    else
        __install_aider
        __install_opencode
    fi
}

# Install Aider if missing or not already up-to-date
__install_aider() {
    echo && log -i 'Setting up Aider ...'
    local -r bin="$LOCAL_DIR/bin/aider"

    # Update if Aider is already installed
    if has_cmd aider; then
        log -i 'Aider already installed'
        exec_ring_log "$bin" --update --yes-always
        log -i "Updated Aider to v$("$bin" --version | awk '{print $2}')"
        return
    fi

    # Download and install Aider binary
    cd "$TEMP_DIR"
    exec_ring_log curl -LsSf https://aider.chat/install.sh -o aider_install.sh
    log -i 'Downloaded installer script'
    exec_ring_log sh aider_install.sh
    cd ~-
    log -i "Installed Aider v$("$bin" --version | awk '{print $2}') to $LOCAL_DIR/bin"

    # Setup bash completion
    mkdir -p "$LOCAL_DIR/share/bash-completion/completions"
    "$LOCAL_DIR/bin/aider" --shell-completions bash > \
        "$LOCAL_DIR/share/bash-completion/completions/aider"
    log -i "Installed Aider bash completion to $LOCAL_DIR/share"
}

# Install OpenCode if missing or not already up-to-date
__install_opencode() {
    echo && log -i 'Setting up OpenCode ...'
    local -r bin="$LOCAL_DIR/bin/opencode"

    # Update if OpenCode is already installed
    if has_cmd opencode; then
        log -i 'OpenCode already installed'
        exec_ring_log "$bin" upgrade
        log -i "Updated OpenCode to v$("$bin" --version)"
        return
    fi

    # Download and install OpenCode binary
    cd "$TEMP_DIR"
    exec_ring_log curl -LsSf https://opencode.ai/install -o opencode_install.sh
    log -i 'Downloaded installer script'
    exec_ring_log bash opencode_install.sh --no-modify-path
    cd ~-

    # Setup symlink in the local directory
    $SUDO ln -sfT "$HOME/.opencode/bin/opencode" "$LOCAL_DIR/bin/opencode"
    log -i "Installed OpenCode v$("$bin" --version) to $LOCAL_DIR/bin"

    # Setup bash completion
    mkdir -p "$LOCAL_DIR/share/bash-completion/completions"
    "$LOCAL_DIR/bin/opencode" completion bash > \
        "$LOCAL_DIR/share/bash-completion/completions/opencode"
    log -i "Installed OpenCode bash completion to $LOCAL_DIR/share"
}
