#!/bin/bash
set -euo pipefail

APP_VERSION="${application_version:-0.2.0}"
BUZZ_IMAGE="ghcr.io/block/buzz:${APP_VERSION}"

export DEBIAN_FRONTEND=noninteractive

# Docker Engine (Compose plugin required by upstream deploy/compose)
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

# Caddy reverse proxy (host TLS; relay stays on loopback :3000)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy

# Materialize .env from the non-hidden Packer template (Packer may skip dotfiles)
if [ -f /opt/buzz/env.template ]; then
  cp /opt/buzz/env.template /opt/buzz/.env
fi
if [ -f /opt/buzz/.env ]; then
  sed -i "s|^BUZZ_IMAGE=.*|BUZZ_IMAGE=${BUZZ_IMAGE}|" /opt/buzz/.env
  chmod 600 /opt/buzz/.env
fi

# Pre-pull images so first boot is faster (sidecar tags match compose.yml pins)
echo "Pulling Buzz stack images (relay ${APP_VERSION})..."
docker pull "${BUZZ_IMAGE}"
docker pull postgres:17.10-alpine
docker pull redis:7.4.10-alpine
docker pull minio/minio:RELEASE.2025-09-07T16-13-09Z
docker pull minio/mc:RELEASE.2025-08-13T08-35-41Z

systemctl enable fail2ban
systemctl restart fail2ban

# Helper scripts and MOTD
chmod +x /opt/buzz/run.sh
chmod +x /opt/start-buzz.sh
chmod +x /opt/stop-buzz.sh
chmod +x /opt/restart-buzz.sh
chmod +x /opt/status-buzz.sh
chmod +x /opt/update-buzz.sh
chmod +x /opt/setup-buzz-domain.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

systemctl daemon-reload
systemctl enable buzz
systemctl enable caddy

echo "Buzz ${APP_VERSION} installation complete."
echo "Stack will start on first boot after secrets are generated."
