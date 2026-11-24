#!/bin/bash

set -e

# Configure UFW firewall
# Allow Coolify web interface (8000), HTTP, HTTPS, and SSH
ufw allow 8000/tcp comment 'Coolify Web Interface'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 6001/tcp comment 'Coolify Realtime'
ufw allow 6002/tcp comment 'Coolify Soketi'
ufw limit ssh/tcp
ufw --force enable

echo "Firewall configured successfully."
# Docker→SSH allows are added after the coolify network exists (narrower than RFC1918).

# Install Docker Engine (version 24+)
# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq

# Install Docker Engine, containerd, and Docker Compose plugin
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker installation
docker --version
docker compose version

echo "Docker installed successfully."

# Configure Docker daemon settings
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

# Restart Docker to apply configuration
systemctl restart docker
systemctl enable docker

echo "Docker daemon configured."

# Create Coolify directories
mkdir -p /data/coolify/{source,ssh,applications,databases,backups,services,proxy,webhooks-during-maintenance}
mkdir -p /data/coolify/ssh/{keys,mux}
mkdir -p /data/coolify/proxy/dynamic

echo "Coolify directories created."

# Download Coolify configuration files (template only, will be configured on first boot)
curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml -o /data/coolify/source/docker-compose.yml
curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml -o /data/coolify/source/docker-compose.prod.yml
curl -fsSL https://cdn.coollabs.io/coolify/.env.production -o /data/coolify/source/.env
curl -fsSL https://cdn.coollabs.io/coolify/upgrade.sh -o /data/coolify/source/upgrade.sh

echo "Coolify configuration files downloaded."

# Set proper permissions (will be reapplied after key generation on first boot)
chown -R 9999:root /data/coolify
chmod -R 700 /data/coolify

echo "Permissions set."

# Create Docker network for Coolify
docker network create --attachable coolify 2>/dev/null || true

echo "Docker network created."

# Allow Coolify containers to reach host SSH (host.docker.internal) via bridge subnets only
allow_docker_ssh_from_subnet() {
    local subnet="$1"
    local comment="$2"
    [ -n "${subnet}" ] || return 0
    ufw allow from "${subnet}" to any port 22 proto tcp comment "${comment}" >/dev/null 2>&1 || true
}

DOCKER0_SUBNET=$(ip -o -f inet addr show docker0 2>/dev/null | awk '{print $4}' | head -1 || true)
COOLIFY_SUBNET=$(docker network inspect coolify -f '{{range .IPAM.Config}}{{.Subnet}}{{println}}{{end}}' 2>/dev/null | head -1 || true)

# Default docker0 if not detectable yet
if [ -z "${DOCKER0_SUBNET}" ]; then
    DOCKER0_SUBNET="172.17.0.0/16"
fi

allow_docker_ssh_from_subnet "${DOCKER0_SUBNET}" "Docker0 to host SSH"
allow_docker_ssh_from_subnet "${COOLIFY_SUBNET}" "Coolify net to host SSH"
echo "UFW: allowed SSH from Docker bridges (${DOCKER0_SUBNET}, ${COOLIFY_SUBNET:-none})."

# Make helper scripts executable (scripts were copied by Packer)
chmod +x /opt/coolify_localhost_setup.sh
chmod +x /opt/configure-coolify-localhost.sh
chmod +x /opt/coolify-sync-localhost-ssh.sh
chmod +x /opt/restart-coolify.sh
chmod +x /opt/stop-coolify.sh
chmod +x /opt/start-coolify.sh
chmod +x /opt/update-coolify.sh
chmod +x /opt/coolify-logs.sh
chmod +x /opt/coolify-status.sh

echo "Helper scripts made executable."

# Install unit file but do not enable yet — 001_onboot performs first start and
# writes /root/coolify_info.txt; enabling here races cloud-init on first boot.
systemctl daemon-reload
systemctl disable coolify.service 2>/dev/null || true

echo "Coolify systemd service installed (enabled after first-boot setup)."

echo "Coolify installation preparation complete."
echo "Coolify will be started on first boot via the onboot script."
