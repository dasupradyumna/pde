##################################### SETUP C++ TOOLING ############################################

manage_cpp() {
    if $OPT__UNINSTALL; then
        cd "$LOCAL_DIR"
        $SUDO rm -rf 'bin/clangd' 'lib/clang'
        echo && log -i 'Uninstalled ClangD'
    else
        __install_clangd
    fi
}

# Install ClangD language server
__install_clangd() {
    echo && log -i 'Setting up ClangD ...'
    local -r ver="${LOCK_VERSIONS[clangd]}"

    # Check if ClangD is already up-to-date
    local curr_ver='(none)'
    if has_cmd clangd; then
        curr_ver="$(clangd --version | awk 'NR==1 {print $3}')"
    fi
    if is_latest_installed 'clangd' "$curr_ver" "$ver"; then return; fi

    # Download ClangD zipfile
    cd "$TEMP_DIR"
    local -r pkg="clangd-linux-${ver}"
    curl_file_github 'clangd/clangd' "$ver" "$pkg.zip" 'pkg.zip'
    log -i "Downloaded v$ver ZIP package"

    # Install ClangD binary
    unzip 'pkg.zip'
    $SUDO install "clangd_$ver/bin/clangd" -D -t "$LOCAL_DIR/bin"
    $SUDO install "clangd_$ver/lib/clang" -D -t "$LOCAL_DIR/lib"
    cd ~-
    log -i "Installed ClangD to $LOCAL_DIR/bin"
}

