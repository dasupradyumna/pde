######################################### SETUP GIT TOOLKIT ########################################

# Execute installation or uninstallation logic based on command-line options
manage_git() {
    if $OPT__UNINSTALL; then
        echo && log -i 'Uninstalling git toolkit ...'

        exec_ring_log $SUDO add-apt-repository -y --remove ppa:git-core/ppa
        log -i 'Removed git PPA repository from APT sources'

        exec_ring_log $SUDO apt-get remove -y git
        exec_ring_log $SUDO apt-get autoremove -y
        exec_ring_log $SUDO apt-get install -y git
        log -i "Downgraded to Git $(git --version | awk '{print $3}')"

        $SUDO rm "$INSTALL_DIR/bin/lazygit" "$INSTALL_DIR/bin/delta" 1>/dev/null
        log -i 'Uninstalled LazyGit and Delta binaries'
    else
        __install_git
        # Needs to be checked manually, since post-checkout hook may not be set up yet
        if ! git config get --local user.email &> /dev/null; then
            local -r user_email='dasupradyumna@gmail.com'
            git config set --local user.email "$user_email"
            log -i "User email for this repository set: '$user_email'"
        fi
        __install_lazygit
        __install_delta
    fi
}

# Install Git if missing or not already up-to-date
__install_git() {
    echo && log -i 'Setting up Git from PPA ...'

    # Check if Git PPA repository is added to APT sources
    if ! apt-cache policy | grep 'http://ppa.launchpad.net/git-core/ppa/ubuntu' &>/dev/null; then
        exec_ring_log $SUDO add-apt-repository -y ppa:git-core/ppa
        log -i 'Added git PPA repository to APT sources'
    else
        log -i 'Git PPA repository already present in APT sources'
    fi

    # Check if Git is already up-to-date
    local installed latest
    read -r installed latest < <(apt_pkg_versions git)
    if is_latest_installed 'git' "$installed" "$latest"; then return; fi

    # Install Git
    exec_ring_log $SUDO apt-get install -y "git=$latest"
    log -i 'Installed Git (APT)'
}

# Install LazyGit if missing or not already up-to-date
__install_lazygit() {
    echo && log -i 'Setting up LazyGit ...'
    local -r ver="${TOOL_VERSIONS[lazygit]}"

    # Check if LazyGit is already up-to-date
    local curr_ver='(none)'
    if command -v lazygit 1>/dev/null; then
        curr_ver="$(lazygit -v | awk -F'version=' '{print $2}' | awk -F',' '{print $1}')"
    fi
    if is_latest_installed 'lazygit' "$curr_ver" "$ver"; then return; fi

    # Download LazyGit tarball
    cd "$TEMP_DIR"
    curl_file_github 'jesseduffield/lazygit' \
        "v$ver" "lazygit_${ver}_Linux_x86_64.tar.gz" 'pkg.tar.gz'
    log -i "Downloaded v$ver TAR package"

    # Install LazyGit binary
    tar xf pkg.tar.gz lazygit
    $SUDO install lazygit -D -t "$INSTALL_DIR/bin"
    cd ~-
    log -i "Installed LazyGit to $INSTALL_DIR/bin"
}

# Install Delta if missing or not already up-to-date
__install_delta() {
    echo && log -i 'Setting up Delta ...'
    local -r ver="${TOOL_VERSIONS[delta]}"

    # Check if Delta is already up-to-date
    local curr_ver='(none)'
    if command -v delta 1>/dev/null; then
        curr_ver="$( delta --version | awk '{print $2}')"
    fi
    if is_latest_installed 'delta' "$curr_ver" "$ver"; then return; fi

    # Download Delta tarball
    cd "$TEMP_DIR"
    local -r pkg="delta-${ver}-x86_64-unknown-linux-gnu"
    curl_file_github 'dandavison/delta' "$ver" "$pkg.tar.gz" 'pkg.tar.gz'
    log -i "Downloaded v$ver TAR package"

    # Install Delta binary
    tar xf pkg.tar.gz "$pkg/delta"
    $SUDO install "$pkg/delta" -D -t "$INSTALL_DIR/bin"
    cd ~-
    log -i "Installed Delta to $INSTALL_DIR/bin"
}
