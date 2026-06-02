#!/bin/bash

set -e

APP_VERSION="${application_version:-latest}"
IMAGE_DIGEST="${image_digest:?image_digest is required}"

# SSH only — codex-universal is a terminal dev environment, not a web app
ufw allow 22/tcp
ufw --force enable
echo "Firewall configured successfully."

echo "Installing Codex CLI..."
curl -fsSL https://chatgpt.com/codex/install.sh | sh

CODEX_BIN="/root/.local/bin/codex"
if [ -x "$CODEX_BIN" ]; then
    ln -sf "$CODEX_BIN" /usr/local/bin/codex
    echo "Codex CLI installed successfully: $(codex --version 2>/dev/null || echo 'version check skipped')"
else
    echo "Error: Codex CLI installation failed"
    exit 1
fi

systemctl enable docker
systemctl start docker

mkdir -p /root/workspace

# Pin image digest from packer variable
sed -i "s|IMAGE_DIGEST=sha256:.*|IMAGE_DIGEST=${IMAGE_DIGEST}|g" /opt/codex-universal/codex-universal.env
sed -i "s|IMAGE=ghcr.io/openai/codex-universal@sha256:.*|IMAGE=ghcr.io/openai/codex-universal@${IMAGE_DIGEST}|g" /opt/codex-universal/codex-universal.env
sed -i "s|TAG=.*|TAG=${APP_VERSION}|g" /opt/codex-universal/codex-universal.env

chmod 600 /opt/codex-universal/codex-universal.env
chmod +x /opt/codex-universal/entrypoint-wrapper.sh
chmod +x /opt/codex-universal/validate-codex-universal-env.sh
chmod +x /opt/codex-universal/shell-codex-universal.sh
chmod +x /opt/codex-universal/start-codex-universal.sh
chmod +x /opt/codex-universal/stop-codex-universal.sh
chmod +x /opt/codex-universal/restart-codex-universal.sh
chmod +x /opt/codex-universal/update-codex-universal.sh
chmod +x /opt/codex-universal/status-codex-universal.sh
chmod +x /opt/codex-universal/codex-universal-version.sh
chmod +x /opt/codex-universal/test-codex-universal.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Temporary env for pre-pulling the pinned image during build (not shipped in snapshot)
cp /opt/codex-universal/codex-universal.env /opt/codex-universal/.env
chmod 600 /opt/codex-universal/.env

echo "Pre-pulling ghcr.io/openai/codex-universal@${IMAGE_DIGEST} (this may take several minutes)..."
cd /opt/codex-universal
docker compose pull
rm -f /opt/codex-universal/.env

systemctl enable codex-universal

echo "Codex Universal installation complete. The dev container starts on first boot."
