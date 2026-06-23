#!/bin/sh

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update -y

sudo apt install docker-ce docker-ce-cli containerd.io -y

curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install node
nvm use node
# NemoClaw install script runs both install and onboard, and onboard will fail without API keys.
# Catch the error and continue.
curl -fsSL https://www.nvidia.com/nemoclaw.sh -o /tmp/nemoclaw-install.sh
NEMOCLAW_NON_INTERACTIVE=1 NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1 bash /tmp/nemoclaw-install.sh
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "Install completed with exit code $EXIT_CODE"
fi
