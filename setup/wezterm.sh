###################################### SETUP WEZTERM EMULATOR ######################################

# Execute installation or uninstallation logic based on command-line options
manage_wezterm() {
    if $OPT__UNINSTALL; then
        cd "$LOCAL_DIR/bin"
        $SUDO rm -rf '.wezterm_appimage' 'wezterm' 'wezterm-mux-server'
        cd ~-
        echo && log -i 'Uninstalled WezTerm'
    else
        echo && log -i 'Setting up WezTerm ...'

        # Download WezTerm AppImage
        cd "$TEMP_DIR"
        curl_file_github 'wezterm/wezterm' \
            'nightly' 'WezTerm-nightly-Ubuntu20.04.AppImage' 'pkg.appimage'
        chmod u+x pkg.appimage
        "./pkg.appimage" --appimage-extract 1>/dev/null
        cd ~-
        log -i 'Downloaded and extracted WezTerm (nightly) AppImage'

        # Check if WezTerm is already up-to-date
        local curr_ver='(none)'
        if command -v wezterm 1>/dev/null; then
            curr_ver="$(wezterm --version | awk '{print $2}')"
        fi
        local -r ver="$("$TEMP_DIR/squashfs-root/AppRun" --version | awk '{print $2}')"
        if is_latest_installed 'wezterm' "$curr_ver" "$ver"; then return; fi

        # Install WezTerm AppImage
        cd "$LOCAL_DIR/bin"
        $SUDO rm -rf '.wezterm_appimage'
        $SUDO mv "$TEMP_DIR/squashfs-root" '.wezterm_appimage'

        # Setup main binary symlinks
        $SUDO ln -sfT '.wezterm_appimage/usr/bin/wezterm' 'wezterm'
        $SUDO ln -sfT '.wezterm_appimage/usr/bin/wezterm-mux-server' 'wezterm-mux-server'
        log -i "Installed WezTerm to $LOCAL_DIR/bin"

        # Setup bash completion
        mkdir -p "$LOCAL_DIR/share/bash-completion/completions"
        wezterm shell-completion --shell bash > \
            "$LOCAL_DIR/share/bash-completion/completions/wezterm"
        log -i "Installed WezTerm bash completion to $LOCAL_DIR/share"

        # Install WezTerm context menu to Nautilus
        if ! $OPT__HEADLESS; then
            mkdir -p "$LOCAL_DIR/share/nautilus-python/extensions"
            $SUDO cp '.wezterm_appimage/usr/share/nautilus-python/extensions/wezterm-nautilus.py' \
                "$LOCAL_DIR/share/nautilus-python/extensions/wezterm-nautilus.py"
        fi

        cd ~-
    fi
}
