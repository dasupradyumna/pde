######################################### SETUP GIT TOOLKIT ########################################
# Handles installation and removal of git, lazygit and delta

setup_git() {
    __install_git
    __install_lazygit
    __install_delta
}

__install_git() {
    # XXX: move to build-from-source method -> version-lock possible
    echo && log -i 'Setting up Git from PPA ...'

    exec_ring_log $SUDO add-apt-repository -y ppa:git-core/ppa
    log -i 'Added git PPA repository to APT sources'

    local version="$(apt-cache policy git | grep Candidate | awk '{print $2}')"
    exec_ring_log $SUDO apt-get install -y "git=$version"
    log -i "Installed $(git --version)"
}

__install_lazygit() {
    echo && log -i 'Setting up LazyGit ...'
    cd "$TEMP_DIR"

    local -r ver='0.54.2'
    local -r pkg="lazygit_${ver}_Linux_x86_64"
    exec_ring_log curl -Lo pkg.tar.gz \
        "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/$pkg.tar.gz"
    log -i "Downloaded v$ver TAR package"

    tar xf pkg.tar.gz lazygit
    $SUDO install lazygit -D -t "$INSTALL_DIR/bin"
    cd ..
    log -i "Installed LazyGit to $INSTALL_DIR/bin"
}

__install_delta() {
    echo && log -i 'Setting up Delta ...'
    cd "$TEMP_DIR"

    local -r ver='0.18.2'
    local -r pkg="delta-${ver}-x86_64-unknown-linux-gnu"
    exec_ring_log curl -Lo pkg.tar.gz \
        "https://github.com/dandavison/delta/releases/download/${ver}/$pkg.tar.gz"
    log -i "Downloaded v$ver TAR package"

    tar xf pkg.tar.gz "$pkg/delta"
    $SUDO install "$pkg/delta" -D -t "$INSTALL_DIR/bin"
    cd ..
    log -i "Installed Delta to $INSTALL_DIR/bin"
}
