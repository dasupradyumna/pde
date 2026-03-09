######################################## DOCKER INSTALLATION #######################################

set -e
SUDO="$([ $(id -u) -ne 0 ] && printf sudo || echo -n)"
title() { echo -e "\n\e[92;1m$1\e[0m\n"; }

if command -v docker 2>1 1>/dev/null; then
    title 'Docker already installed on this system. Use APT to upgrade.' && exit
fi


title "I. Add Docker's official GPG key"

$SUDO apt update -y
$SUDO apt install -y ca-certificates curl
$SUDO install -m 0755 -d /etc/apt/keyrings
$SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
$SUDO chmod a+r /etc/apt/keyrings/docker.asc


title 'II. Add the repository to APT sources'

$SUDO tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF


title 'III. Install docker packages'

$SUDO apt update -y
$SUDO apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


title 'IV. Allow $USER to access docker daemon via CLI' # Only root has access by default

$SUDO groupadd docker 2>/dev/null || true
$SUDO usermod -aG docker ${USER:-root}
echo 'Created docker group and added current user'


title 'V. Ensure these services are started on boot-up'

$SUDO systemctl enable docker.service
$SUDO systemctl enable containerd.service


title 'Please reboot for changes to take effect! \
    Then, run `docker run hello-world` to check if the installation was successful.'
