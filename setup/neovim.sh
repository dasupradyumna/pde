######################################## SETUP NEOVIM EDITOR #######################################

# Execute installation or uninstallation logic based on command-line options
manage_neovim() {
    if $OPT__UNINSTALL; then
        cd "$LOCAL_DIR"
        $SUDO rm -rf 'bin/ripgrep' 'bin/xclip'
        echo && log -i 'Uninstalled RipGrep and XClip'

        $SUDO rm -rf 'bin/nvim' 'lib/nvim' 'share/nvim/runtime' 'share/man/man1/nvim.1'
        log -i 'Uninstalled Neovim'
        cd ~-
    else
        __install_ripgrep
        __install_xclip
        __install_neovim
    fi
}

# Install RipGrep if missing or not already up-to-date
__install_ripgrep() {
    echo && log -i 'Setting up RipGrep ...'
    local -r ver="${LOCK_VERSIONS[ripgrep]}"

    # Check if RipGrep is already up-to-date
    local curr_ver='(none)'
    if has_cmd rg; then
        curr_ver="$(rg --version | awk 'NR==1 {print $2}')"
    fi
    if is_latest_installed 'ripgrep' "$curr_ver" "$ver"; then return; fi

    # Download RipGrep tarball
    cd "$TEMP_DIR"
    local -r pkg="ripgrep-${ver}-x86_64-unknown-linux-musl"
    curl_file_github 'BurntSushi/ripgrep' "$ver" "$pkg.tar.gz" 'pkg.tar.gz'
    log -i "Downloaded v$ver TAR package"

    # Install RipGrep binary
    tar xf pkg.tar.gz "$pkg/rg"
    $SUDO install "$pkg/rg" -D -t "$LOCAL_DIR/bin"
    cd ~-
    log -i "Installed RipGrep to $LOCAL_DIR/bin"
}

# Install XClip if missing or not already up-to-date
__install_xclip() {
    echo && log -i 'Setting up XClip ...'

    # Check if XClip is already up-to-date
    local installed latest
    read -r installed latest < <(apt_pkg_versions xclip)
    installed="${FREE_VERSIONS[xclip]:-(none)}"
    echo "xclip    $latest" >> "$FREE_VERSIONS_FILE"
    if is_latest_installed 'xclip' "$installed" "$latest"; then return; fi

    # If installation scope is system-level
    if $OPT__SYSTEM_SCOPE; then
        exec_ring_log $SUDO apt-get install -y "xclip=$latest"
        log -i 'Installed XClip (APT-system)'
    else
        cd "$TEMP_DIR"
        apt download "xclip=$latest" &> /dev/null
        dpkg -x "$(find -type f -name 'xclip*.deb')" 'xclip'
        log -i 'Downloaded and extracted APT package'
        mv 'xclip/usr/bin/xclip' "$LOCAL_DIR/bin"
        log -i "Installed XClip (APT-user)"
        cd ~-
    fi
}

# Install Neovim of specified version
__install_neovim() {
    echo && log -i 'Setting up Neovim ...'
    local -r ver="${LOCK_VERSIONS[neovim]}"

    git clone -b "v$ver" --depth 1 'https://github.com/neovim/neovim' "$TEMP_DIR/neovim" &>/dev/null
    log -i 'Cloned GitHub repository'

    cd "$TEMP_DIR/neovim"
    exec_ring_log make -j8 CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$LOCAL_DIR"
    log -i "Built v$ver from source"

    exec_ring_log $SUDO make install
    log -i "Installed Neovim to $LOCAL_DIR/bin"
    cd ~-
}
