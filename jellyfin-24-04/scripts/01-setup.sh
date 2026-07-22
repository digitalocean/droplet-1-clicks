#!/bin/bash
set -Eeuo pipefail

APP_VERSION="${application_version:?application_version must be set}"

echo "==> Enabling Docker..."
systemctl enable docker
systemctl start docker

echo "==> Installing Caddy..."
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy

mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
touch /var/log/caddy/access.json
chown caddy:caddy /var/log/caddy/access.json

# Defer Caddy until 001_onboot writes the Jellyfin Caddyfile (avoid stock config).
systemctl disable --now caddy || true

echo "==> Preparing Jellyfin data directories..."
mkdir -p /var/lib/jellyfin/config /var/lib/jellyfin/cache /var/lib/jellyfin/media

cat > /opt/jellyfin.env <<EOF
JELLYFIN_VERSION=${APP_VERSION}
JELLYFIN_IMAGE=jellyfin/jellyfin:${APP_VERSION}
EOF
chmod 644 /opt/jellyfin.env

echo "==> Pulling Jellyfin ${APP_VERSION} (start deferred to first boot)..."
docker pull "jellyfin/jellyfin:${APP_VERSION}"

echo "==> Setting script permissions..."
chmod +x /opt/start-jellyfin.sh
chmod +x /opt/stop-jellyfin.sh
chmod +x /opt/restart-jellyfin.sh
chmod +x /opt/status-jellyfin.sh
chmod +x /opt/update-jellyfin.sh
chmod +x /opt/setup-jellyfin-domain.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

echo "==> Registering Jellyfin unit (enabled/started on first boot)..."
systemctl daemon-reload

echo "==> Jellyfin setup complete."
