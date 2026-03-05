######################################## DEBUG ADAPTER SETUP #######################################

manage_dap() {
    if $OPT__UNINSTALL; then
        cd "$LOCAL_DIR/bin"
        $SUDO rm -rf '.codelldb' 'codelldb' '.debugpy' 'debugpy'
        echo && log -i 'Uninstalled CodeLLDB and DebugPy'
    else
        __install_codelldb
        __install_debugpy
    fi
}

# Install CodeLLDB debug adapter
__install_codelldb() {
    echo && log -i 'Setting up CodeLLDB ...'
    local -r ver="${LOCK_VERSIONS[codelldb]}"

    # Check if CodeLLDB is already up-to-date
    # XXX: this won't work. No version flag is exposed. We need to check package.json.
    local curr_ver='(none)'
    if has_cmd codelldb; then
        curr_ver="$(codelldb --version | awk 'NR==1 {print $3}')"
    fi
    if is_latest_installed 'codelldb' "$curr_ver" "$ver"; then return; fi

    # Download CodeLLDB zipfile
    cd "$TEMP_DIR"
    local -r pkg='codelldb-linux-x64'
    curl_file_github 'vadimcn/codelldb' "$ver" "$pkg.vsix" 'pkg.vsix'
    log -i "Downloaded v$ver VSIX (ZIP) package"

    # Install CodeLLDB package
    mkdir '.codelldb'
    unzip 'pkg.vsix' -d '.codelldb'
    $SUDO mv '.codelldb' "$LOCAL_DIR/bin"

    # Setup main binary symlink
    cd "$LOCAL_DIR/bin"
    $SUDO ln -sfT '.codelldb/extension/adapter/codelldb' 'codelldb'
    cd ~-
    log -i "Installed CodeLLDB to $LOCAL_DIR/bin"
}

__install_debugpy() {
    echo && log -i 'Setting up DebugPy ...'
    local -r ver="${LOCK_VERSIONS[debugpy]}"

    # Check if DebugPy is already up-to-date
    local curr_ver='(none)'
    if has_cmd debugpy; then
        curr_ver="$(debugpy --version 2>/dev/null)"
    fi
    if is_latest_installed 'debugpy' "$curr_ver" "$ver"; then return; fi

    # Install DebugPy Pip package to virtual environment
    cd "$LOCAL_DIR/bin"
    rm -rf '.debugpy'
    python3 -m venv '.debugpy'
    source '.debugpy/bin/activate'
    pip install "debugpy==$ver"
    deactivate

    # Setup main binary symlink
    $SUDO ln -sfT '.debugpy/bin/debugpy' 'debugpy'
    cd ~-
    log -i "Installed DebugPy to $LOCAL_DIR/bin"
}
