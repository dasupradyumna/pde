######################################### SETUP GIT TOOLKIT ########################################
# Handles installation and removal of git, lazygit and delta

setup_git() {
    __install_git
    __install_lazygit
    __install_delta
}

__install_git() {
    echo && log -i 'Installing Git from PPA ...'

    exec_ring_log add-apt-repository -y ppa:git-core/ppa
    log -i 'Added git PPA repository to APT sources'

    local version="$(apt-cache policy git | grep Candidate | awk '{print $2}')"
    exec_ring_log apt-get install -y "git=$version"
    log -i "Installed $(git --version)"
}

__install_lazygit() {
    echo && log -i 'Installing LazyGit ...'
    cd "$TMPDIR"
    local -r ver='0.54.2'
    local -r pkg="lazygit_${ver}_Linux_x86_64"
    curl -Lo pkg.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/$pkg.tar.gz"
    tar xf pkg.tar.gz lazygit
    install lazygit -D -t /usr/local/bin # ~/.local/bin if user
    cd ..
}

__install_delta() {
    echo && log -i 'Installing Delta ...'
    cd "$TMPDIR"
    local -r ver='0.18.2'
    local -r pkg="delta-${ver}-x86_64-unknown-linux-gnu"
    curl -Lo pkg.tar.gz "https://github.com/dandavison/delta/releases/download/${ver}/$pkg.tar.gz"
    tar xf pkg.tar.gz "$pkg/delta"
    install "$pkg/delta" -D -t /usr/local/bin # ~/.local/bin if user
    cd ..
}
