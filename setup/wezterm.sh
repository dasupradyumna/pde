###################################### SETUP WEZTERM EMULATOR ######################################

# Execute installation or uninstallation logic based on command-line options
manage_wezterm() {
    if $OPT__SKIP_WEZTERM; then echo && log -i 'Skipped WezTerm'; return; fi

    if $OPT__UNINSTALL; then
        cd "$INSTALL_DIR/bin"
        $SUDO rm -rf '.wezterm_appimage' 'wezterm'
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

        # Install WezTerm binary
        cd "$INSTALL_DIR/bin"
        $SUDO rm -rf '.wezterm_appimage'
        $SUDO mv "$TEMP_DIR/squashfs-root" '.wezterm_appimage'
        $SUDO ln -sfT '.wezterm_appimage/AppRun' 'wezterm'
        log -i "Installed WezTerm to $INSTALL_DIR/bin"
        cd ~-
    fi
}
