#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Install Caddy (reverse proxy with automatic shortlived TLS)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" >/etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

systemctl enable docker
systemctl start docker

systemctl enable fail2ban
systemctl restart fail2ban

# Caddy is configured on first boot / setup; keep disabled until then
systemctl disable caddy || true
systemctl stop caddy || true

chmod +x /root/plausible-setup.sh
chmod +x /opt/setup-plausible-domain.sh
chmod +x /opt/start-plausible.sh
chmod +x /opt/stop-plausible.sh
chmod +x /opt/restart-plausible.sh
chmod +x /opt/status-plausible.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

mkdir -p /docker/plausible
