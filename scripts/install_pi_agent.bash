####################################### PI AGENT INSTALLATION ######################################
set -e

# Script arguments
PI_VER_TARGET="$1"       # Desired Pi version
INSTALL_PREFX="$2"       # PDE installation prefix

# Display information in bold bright green text
info() { echo -e "\n\e[92;1m>> $1\e[0m\n"; }

# Get latest version of package using GitHub API
# Argument: (1) "org/proj"
get_latest_version() {
    echo "$(curl -s https://api.github.com/repos/$1/releases/latest | jq -r '.tag_name')"
}

# Install NVM latest version, if needed
install_nvm() {
    # Get latest NVM release version from GitHub
    local -r ver_latest="$(get_latest_version 'nvm-sh/nvm')"
    info "Latest NVM release: $ver_latest"

    # NVM contained inside PDE installation
    export NVM_DIR="$INSTALL_PREFX/lib/nvm"
    mkdir -p "$NVM_DIR"

    # Check if NVM is already installed and get current version
    if [ -n "$(ls -A "$NVM_DIR")" ]; then
        local -r ver_current="v$(source "$NVM_DIR/nvm.sh" &>/dev/null && nvm --version)"
        echo -e "Installed NVM version: $ver_current\n"
    else
        local -r ver_current=
        echo -e "NVM not found on this system!\n"
    fi

    # Install NVM latest version if it does not match current version
    if [ "$ver_current" != "$ver_latest" ]; then
        # Ensure profile files are untouched by NVM installer
        export PROFILE=/dev/null
        # Download and execute the NVM installer
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$ver_latest/install.sh" | bash
        info "Installed NVM $ver_latest"
    else
        info "Latest NVM $ver_latest already installed"
    fi

    # Install the LTS version of node and npm
    source "$NVM_DIR/nvm.sh"
    nvm install --lts

    # Setup bash completion for node and npm
    local -r comp_dir="$INSTALL_PREFX/share/bash-completion/completions"
    cp "$NVM_DIR/bash_completion" "$comp_dir/nvm"
    npm completion >> "$comp_dir/npm"
    node --completion-bash >> "$comp_dir/node"
    info 'Installed node & npm, along with bash completion'
}

install_prettier() {
    # Get latest Prettier release version from GitHub
    local -r ver_latest="$(get_latest_version 'prettier/prettier')"
    info "Latest Prettier release: $ver_latest"

    # Check if Prettier is already installed and get current version
    if npm list --global prettier &>/dev/null; then
        local -r ver_current="$(npm list --global --json prettier | \
                                    jq -r '.dependencies.prettier.version')"
        echo -e "Installed Prettier version: $ver_current\n"
    else
        local -r ver_current=
        echo -e "Prettier not found on this system!\n"
    fi

    # Install Prettier latest version if it does not match current version
    if [ "$ver_current" != "$ver_latest" ]; then
        npm install --global --save-exact "prettier@$ver_latest"
        info "Installed Prettier $ver_latest"
    else
        info "Latest Prettier $ver_latest already installed"
    fi
}

main() {
    install_nvm
    install_prettier

    # Version checking is not required for Pi coding agent
    # This script would not be executed by PDE manager, if versions match
    npm install --global --ignore-scripts "@earendil-works/pi-coding-agent@$PI_VER_TARGET"
    info 'Installed pi coding agent'
}

main $@
