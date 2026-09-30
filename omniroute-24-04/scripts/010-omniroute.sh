#!/bin/bash
set -euo pipefail

APP_VERSION="${application_version:-latest}"
OMNIROUTE_IMAGE="diegosouzapw/omniroute:${APP_VERSION}"

export DEBIAN_FRONTEND=noninteractive

# Docker Engine + Compose plugin
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl enable docker
systemctl restart docker

docker --version
docker compose version

# Caddy reverse proxy (host TLS; OmniRoute stays on loopback :20128)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

# Materialize .env from the non-hidden Packer template (Packer may skip dotfiles)
if [ -f /opt/omniroute/env.template ]; then
  cp /opt/omniroute/env.template /opt/omniroute/.env
fi
if [ -f /opt/omniroute/.env ]; then
  sed -i "s|^OMNIROUTE_IMAGE=.*|OMNIROUTE_IMAGE=${OMNIROUTE_IMAGE}|" /opt/omniroute/.env
  chmod 600 /opt/omniroute/.env
fi

# Convenience symlink for agent 1-Click convention (/opt/<app>.env)
ln -sfn /opt/omniroute/.env /opt/omniroute.env

# Pre-pull images so first boot is faster
echo "Pulling OmniRoute stack images (${OMNIROUTE_IMAGE})..."
docker pull "${OMNIROUTE_IMAGE}"
docker pull docker.io/library/redis:8.6.5-alpine

systemctl enable fail2ban
systemctl restart fail2ban

# Helper scripts and MOTD
chmod +x /opt/omniroute/run.sh
chmod +x /opt/start-omniroute.sh
chmod +x /opt/stop-omniroute.sh
chmod +x /opt/restart-omniroute.sh
chmod +x /opt/status-omniroute.sh
chmod +x /opt/update-omniroute.sh
chmod +x /opt/apply-inference-from-env.sh
chmod +x /opt/retry-apply-inference-after-cloud-init.sh
chmod +x /opt/setup-omniroute-domain.sh
chmod +x /opt/omniroute/inference-helpers.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

systemctl daemon-reload
systemctl enable omniroute
systemctl enable caddy

echo "OmniRoute (${OMNIROUTE_IMAGE}) installation complete."
echo "Stack will start on first boot after secrets are generated."
