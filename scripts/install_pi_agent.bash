####################################### PI AGENT INSTALLATION ######################################
PI_VERSION="$1"  # Desired Pi version
set -e
info() { echo -e "\n\e[92;1m>> $1\e[0m\n"; }

# Get latest NVM release version from GitHub
NVM_VERSION="$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')"
info "Latest NVM release: $NVM_VERSION"

# Ensure profile files are untouched by NVM installer
export PROFILE=/dev/null
# NVM installation contained inside PDE
export NVM_DIR="$HOME/.pde/lib/nvm"
mkdir -p "$NVM_DIR"
# Download and execute the NVM installer
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
info "Installed NVM $NVM_VERSION"

# Install the LTS version of node and npm
source "$NVM_DIR/nvm.sh"
nvm install --lts

# Setup bash completion for node and npm
COMP_DIR="$HOME/.pde/share/bash-completion/completions"
cp "$NVM_DIR/bash_completion" "$COMP_DIR/nvm"
npm completion >> "$COMP_DIR/npm"
node --completion-bash >> "$COMP_DIR/node"
info 'Installed node & npm, along with bash completion'

# Install specified version of Pi coding agent
npm install -g --ignore-scripts "@earendil-works/pi-coding-agent@$PI_VERSION"
info 'Installed pi coding agent'
