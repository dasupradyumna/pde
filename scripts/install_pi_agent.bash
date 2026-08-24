####################################### PI AGENT INSTALLATION ######################################
set -e

# Script arguments
PI_VER_TARGET="$1"       # Desired Pi version
INSTALL_PREFX="$2"       # PDE installation prefix

# Display information in bold bright green text
info() { echo -e "\n\e[92;1m>> $1\e[0m\n"; }

# Install NVM latest version, if needed
install_nvm() {
    # Get latest NVM release version from GitHub
    NVM_VER_LATEST="$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | \
                        jq -r '.tag_name')"
    info "Latest NVM release: $NVM_VER_LATEST"

    # NVM contained inside PDE installation
    export NVM_DIR="$INSTALL_PREFX/lib/nvm"
    mkdir -p "$NVM_DIR"

    # Check if NVM is already installed and get current version
    if [ -n "$(ls -A "$NVM_DIR")" ]; then
        NVM_VER_CURRENT="v$(source "$NVM_DIR/nvm.sh" &>/dev/null && nvm --version)"
        echo -e "Installed NVM version: $NVM_VER_CURRENT\n"
    else
        NVM_VER_CURRENT=
        echo -e "NVM not found on this system!\n"
    fi

    # Install NVM latest version if it does not match current version
    if [ "$NVM_VER_CURRENT" != "$NVM_VER_LATEST" ]; then
        # Ensure profile files are untouched by NVM installer
        export PROFILE=/dev/null
        # Download and execute the NVM installer
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VER_LATEST/install.sh" | bash
        info "Installed NVM $NVM_VER_LATEST"
    else
        info "Latest NVM $NVM_VER_LATEST already installed"
    fi

    # Install the LTS version of node and npm
    source "$NVM_DIR/nvm.sh"
    nvm install --lts

    # Setup bash completion for node and npm
    COMP_DIR="$INSTALL_PREFX/share/bash-completion/completions"
    cp "$NVM_DIR/bash_completion" "$COMP_DIR/nvm"
    npm completion >> "$COMP_DIR/npm"
    node --completion-bash >> "$COMP_DIR/node"
    info 'Installed node & npm, along with bash completion'
}

main() {
    install_nvm

    # Version checking is not required for Pi coding agent
    # This script would not be executed by PDE manager, if versions match
    npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@$PI_VER_TARGET"
    info 'Installed pi coding agent'
}

main $@
