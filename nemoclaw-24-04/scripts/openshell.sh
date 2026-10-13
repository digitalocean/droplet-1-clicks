#!/bin/sh
set -e

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

# Keep current Node (nvm "node" alias) so OpenClaw / auto-update paths that
# require Node >=24.16 or >=26.1 stay satisfied. NemoClaw itself only needs >=22.19.
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

{
  echo 'export NVM_DIR="$HOME/.nvm"'
  echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
} >> ~/.bashrc

nvm install node
nvm use node
nvm alias default node

# Install NemoClaw the way NVIDIA's installer does — not `npm install -g git+...`.
# Global git installs run package prepare, which calls npm-link-or-shim while npm is
# still renaming lib/node_modules/nemoclaw → EISDIR (exit 235).
APP_VERSION="${application_version:-lkg}"
case "$APP_VERSION" in
  latest|Latest) APP_VERSION="lkg" ;;
esac

NEMOCLAW_SRC="${HOME}/.nemoclaw/source"
rm -rf "$NEMOCLAW_SRC"
mkdir -p "$(dirname "$NEMOCLAW_SRC")"

git init --quiet "$NEMOCLAW_SRC"
git -C "$NEMOCLAW_SRC" remote add origin https://github.com/NVIDIA/NemoClaw.git
git -C "$NEMOCLAW_SRC" fetch --quiet --depth 1 origin "+${APP_VERSION}:refs/nemoclaw-install/target"
git -C "$NEMOCLAW_SRC" -c advice.detachedHead=false checkout --quiet --detach refs/nemoclaw-install/target
# Shallow clone only has the requested ref; fetch version tags for `git describe`.
git -C "$NEMOCLAW_SRC" fetch --depth=1 origin 'refs/tags/v*:refs/tags/v*' 2>/dev/null || true

export NEMOCLAW_INSTALLING=1
cd "$NEMOCLAW_SRC"

node scripts/lib/openshell-sdk-install.mts prepare
npm install --ignore-scripts --prefer-offline --include=optional --@nvidia:registry=https://npm.pkg.github.com
node scripts/lib/openshell-sdk-install.mts check

npm run --if-present build:cli
( cd nemoclaw && npm ci --ignore-scripts && npm run build )
npm link --ignore-scripts

nemoclaw --version
