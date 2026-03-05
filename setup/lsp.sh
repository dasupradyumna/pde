####################################### LANGUAGE SERVER SETUP ######################################

# TODO: setup rust toolchain - includes rustup | rustfmt | rust-analyzer | clippy
#       install rust treesitter

manage_lsp() {
    if $OPT__UNINSTALL; then
        cd "$LOCAL_DIR"
        $SUDO rm -rf 'bin/clangd' 'lib/clang' 'lua-language-server' '.lua-language-server'
        echo && log -i 'Uninstalled ClangD and LuaLS'
    else
        __install_clangd
        __install_lua_ls
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

# Install LuaLS language server
__install_lua_ls() {
    echo && log -i 'Setting up LuaLS ...'
    local -r ver="${LOCK_VERSIONS[lua-language-server]}"

    # Check if LuaLS is already up-to-date
    local curr_ver='(none)'
    if has_cmd lua-language-server; then
        curr_ver="$(lua-language-server --version)"
    fi
    if is_latest_installed 'lua-language-server' "$curr_ver" "$ver"; then return; fi

    # Download LuaLS tarball
    cd "$TEMP_DIR"
    local -r pkg="lua-language-server-$ver-linux-x64"
    curl_file_github 'LuaLS/lua-language-server' "$ver" "$pkg.tar.gz" 'pkg.tar.gz'
    log -i "Downloaded v$ver TAR package"

    # Install LuaLS package
    mkdir '.lua-language-server'
    tar xf '../pkg.tar.gz' -C '.lua-language-server'
    $SUDO mv '.lua-language-server' "$LOCAL_DIR/bin"

    # Setup main binary symlink
    cd "$LOCAL_DIR/bin"
    $SUDO ln -sfT '.lua-language-server/bin/lua-language-server' 'lua-language-server'
    cd ~-
    log -i "Installed LuaLS to $LOCAL_DIR/bin"
}
