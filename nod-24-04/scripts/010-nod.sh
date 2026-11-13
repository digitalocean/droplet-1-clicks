#!/bin/bash
set -euo pipefail

APP_VERSION="${application_version:-0.7.2}"
NOD_TAG="nod-v${APP_VERSION}"
NOD_DIR="/opt/nod"
SELF_HOST_DIR="${NOD_DIR}/deployment/self-host"

# Open HTTP/HTTPS for Caddy; limit SSH.
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw limit ssh/tcp
ufw --force enable

# Install Docker Engine 25+ with Compose v2 (Nod requires API >= 1.44).
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker --version
docker compose version

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
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

# Install Caddy for shortlived IP TLS (Marketplace pattern).
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -qq
apt-get install -y -qq caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
touch /var/log/caddy/access.json
chown caddy:caddy /var/log/caddy/access.json

# Clone Nod at the pinned release tag and pre-build images.
if [ -d "${NOD_DIR}/.git" ]; then
  rm -rf "${NOD_DIR}"
fi
git clone --depth 1 --branch "${NOD_TAG}" https://github.com/n8n-io/nod.git "${NOD_DIR}"

# Temporary .env so compose can validate/build; secrets are regenerated on first boot.
(
  cd "${SELF_HOST_DIR}"
  unset NOD_AUTH_TOKEN NOD_VAULT_KEY NOD_POSTGRES_PASSWORD || true
  COMPOSE_PROJECT_NAME="nod-image-build" sh setup.sh
  docker compose --file compose.yaml --env-file .env build
  # Drop packer-time secrets so every droplet gets unique keys via onboot.
  rm -f .env
)

systemctl enable fail2ban
systemctl restart fail2ban

# Make helper and lifecycle scripts executable.
chmod +x /opt/start-nod.sh
chmod +x /opt/stop-nod.sh
chmod +x /opt/restart-nod.sh
chmod +x /opt/status-nod.sh
chmod +x /opt/update-nod.sh
chmod +x /opt/setup-nod-domain.sh
chmod +x /opt/nod-compose.sh
chmod +x /opt/apply-inference-from-env.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /var/lib/digitalocean/inference-models.sh
chmod 600 /opt/nod.env


# Enable but do not start yet — first boot generates secrets and public URL.
systemctl enable nod.service
systemctl disable caddy || true
systemctl stop caddy || true

echo "Nod ${NOD_TAG} installed and images pre-built."
