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

cp /opt/codex-universal/codex-universal.env /opt/codex-universal/.env
chmod 600 /opt/codex-universal/.env

echo "Pre-pulling ghcr.io/openai/codex-universal@${IMAGE_DIGEST} (this may take several minutes)..."
cd /opt/codex-universal
docker compose pull

echo "Pre-warming container: running setup_universal.sh to bake language runtimes into snapshot..."
docker compose up -d

echo "Waiting for setup_universal.sh to complete (this may take several minutes)..."
until docker exec codex-universal ps aux 2>/dev/null | grep -q '[s]leep infinity'; do
    echo "  Still setting up language runtimes..."
    sleep 30
done
echo "Language runtime setup complete."

# Stop (not down) to preserve the container's writable layer in the snapshot.
# On first boot, docker compose up restarts this stopped container rather than
# creating a fresh one, so runtimes are already in place.
docker compose stop

# .env is not shipped in the snapshot — 001_onboot recreates it from the template.
# Docker Compose compares env values at up-time: if the user provides no
# CODEX_ENV_* overrides, the recreated .env is identical and the stopped
# container is reused; if overrides differ, Compose correctly recreates it.
rm -f /opt/codex-universal/.env

systemctl enable codex-universal

echo "Codex Universal installation complete. Language runtimes are pre-warmed in the snapshot."
