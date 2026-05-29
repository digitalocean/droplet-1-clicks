#!/bin/sh
set -e

APP_VERSION="${application_version:-v2.8.3}"

# Open required ports for HTTPS reverse proxy
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# Install Caddy (reverse proxy with automatic TLS)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

systemctl enable docker
systemctl start docker

# Pin image tag from packer variable
sed -i "s|TAG=latest|TAG=${APP_VERSION}|g" /opt/twenty/twenty.env

chmod +x /opt/twenty/start-twenty.sh
chmod +x /opt/twenty/stop-twenty.sh
chmod +x /opt/twenty/restart-twenty.sh
chmod +x /opt/twenty/update-twenty.sh
chmod +x /opt/twenty/status-twenty.sh
chmod +x /opt/twenty/setup-twenty-domain.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Temporary env for pre-pulling images during build
cp /opt/twenty/twenty.env /opt/twenty/.env
sed -i 's|PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT|buildtime-placeholder|g' /opt/twenty/.env

cd /opt/twenty
docker compose pull
rm -f /opt/twenty/.env

systemctl enable twenty

echo "Twenty CRM installation completed. Services start on first boot."
