#!/bin/bash

set -e

echo "Starting Plex Media Server installation..."

# Firewall: SSH/HTTP/HTTPS via common/scripts/014-ufw-http.sh; open Plex remote-access port
ufw allow 32400/tcp

systemctl enable docker
systemctl start docker

systemctl enable --now fail2ban

# Install Caddy (reverse proxy with automatic TLS)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

mkdir -p /opt/plex/{config,transcode,media}

sed -i "s|PLEX_VERSION_PLACEHOLDER|${application_version}|g" /opt/plex/docker-compose.yml

chmod +x /opt/start-plex.sh
chmod +x /opt/stop-plex.sh
chmod +x /opt/restart-plex.sh
chmod +x /opt/update-plex.sh
chmod +x /opt/claim-plex.sh
chmod +x /opt/enable-plex-proxy.sh
chmod +x /opt/setup-plex-domain.sh
chmod +x /opt/status-plex.sh
chmod +x /opt/plex-get-public-ip.sh
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /etc/update-motd.d/99-one-click

cd /opt/plex
docker compose pull --quiet

systemctl enable plex
systemctl enable caddy

echo "Plex Media Server installation completed."
