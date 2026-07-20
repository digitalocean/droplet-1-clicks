#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating system packages..."
apt-get update && apt-get upgrade -y

echo "==> Installing prerequisites..."
apt-get install -y curl gnupg apt-transport-https

echo "==> Downloading and verifying official Jellyfin installer..."
cd /tmp
curl -s https://repo.jellyfin.org/install-debuntu.sh -O
curl -s https://repo.jellyfin.org/install-debuntu.sh.sha256sum -O

# Validate checksum before running
sha256sum -c install-debuntu.sh.sha256sum

echo "==> Executing Jellyfin installation script..."
bash install-debuntu.sh

echo "==> Ensuring Jellyfin starts on boot..."
systemctl daemon-reload
systemctl enable jellyfin
systemctl start jellyfin

echo "==> Opening Jellyfin web UI port in UFW..."
ufw allow 8096/tcp

echo "==> Cleaning up build history..."
rm -f /tmp/install-debuntu.sh*
apt-get autoremove -y
apt-get clean