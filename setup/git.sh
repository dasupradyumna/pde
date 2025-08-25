######################################### SETUP GIT TOOLKIT ########################################
# Handles installation and removal of git, lazygit and delta

setup_git() {
    __install_git
    # Needs to be checked manually, since post-checkout hook may not be set up yet
    if ! git config get --local user.email &> /dev/null; then
        local -r user_email='dasupradyumna@gmail.com'
        git config set --local user.email "$user_email"
        log -i "User email for this repository set: '$user_email'"
    fi

    __install_lazygit
    __install_delta
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
    log -i "Installed $(git --version)"
}

# Install LazyGit if missing or not already up-to-date
__install_lazygit() {
    echo && log -i 'Setting up LazyGit ...'
    local -r ver='0.54.2'

    # Check if LazyGit is already installed
    local curr_ver='(none)'
    if [ -f "$INSTALL_DIR/bin/lazygit" ]; then
        curr_ver=$(lazygit -v | awk -F'version=' '{print $2}' | awk -F',' '{print $1}')
    fi
    if is_latest_installed 'lazygit' "$curr_ver" "$ver"; then return; fi

    # Download LazyGit tarball
    cd "$TEMP_DIR"
    local -r pkg="lazygit_${ver}_Linux_x86_64"
    exec_ring_log curl -Lo pkg.tar.gz \
        "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/$pkg.tar.gz"
    log -i "Downloaded v$ver TAR package"

    # Install LazyGit binary
    tar xf pkg.tar.gz lazygit
    $SUDO install lazygit -D -t "$INSTALL_DIR/bin"
    cd ..
    log -i "Installed LazyGit to $INSTALL_DIR/bin"
}

# Install Delta if missing or not already up-to-date
__install_delta() {
    echo && log -i 'Setting up Delta ...'
    local -r ver='0.18.2'

    # Check if Delta is already installed
    local curr_ver='(none)'
    if [ -f "$INSTALL_DIR/bin/delta" ]; then
        curr_ver=$( delta --version | awk '{print$2}')
    fi
    if is_latest_installed 'delta' "$curr_ver" "$ver"; then return; fi

    # Download Delta tarball
    cd "$TEMP_DIR"
    local -r pkg="delta-${ver}-x86_64-unknown-linux-gnu"
    exec_ring_log curl -Lo pkg.tar.gz \
        "https://github.com/dandavison/delta/releases/download/${ver}/$pkg.tar.gz"
    log -i "Downloaded v$ver TAR package"

    # Install Delta binary
    tar xf pkg.tar.gz "$pkg/delta"
    $SUDO install "$pkg/delta" -D -t "$INSTALL_DIR/bin"
    cd ..
    log -i "Installed Delta to $INSTALL_DIR/bin"
}
