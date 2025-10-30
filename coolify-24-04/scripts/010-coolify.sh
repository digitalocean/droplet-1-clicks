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

# Generate SSH key for Coolify server management
ssh-keygen -f /data/coolify/ssh/keys/id.root@host.docker.internal -t ed25519 -N '' -C root@coolify

# Add the public key to authorized_keys
cat /data/coolify/ssh/keys/id.root@host.docker.internal.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

echo "SSH keys configured."

# Download Coolify configuration files
curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.yml -o /data/coolify/source/docker-compose.yml
curl -fsSL https://cdn.coollabs.io/coolify/docker-compose.prod.yml -o /data/coolify/source/docker-compose.prod.yml
curl -fsSL https://cdn.coollabs.io/coolify/.env.production -o /data/coolify/source/.env
curl -fsSL https://cdn.coollabs.io/coolify/upgrade.sh -o /data/coolify/source/upgrade.sh

echo "Coolify configuration files downloaded."

# Set proper permissions
chown -R 9999:root /data/coolify
chmod -R 700 /data/coolify

echo "Permissions set."

# Generate secure random values for .env file
sed -i "s|APP_ID=.*|APP_ID=$(openssl rand -hex 16)|g" /data/coolify/source/.env
sed -i "s|APP_KEY=.*|APP_KEY=base64:$(openssl rand -base64 32)|g" /data/coolify/source/.env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$(openssl rand -base64 32)|g" /data/coolify/source/.env
sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$(openssl rand -base64 32)|g" /data/coolify/source/.env
sed -i "s|PUSHER_APP_ID=.*|PUSHER_APP_ID=$(openssl rand -hex 32)|g" /data/coolify/source/.env
sed -i "s|PUSHER_APP_KEY=.*|PUSHER_APP_KEY=$(openssl rand -hex 32)|g" /data/coolify/source/.env
sed -i "s|PUSHER_APP_SECRET=.*|PUSHER_APP_SECRET=$(openssl rand -hex 32)|g" /data/coolify/source/.env

echo "Environment variables generated."

# Create Docker network for Coolify
docker network create --attachable coolify 2>/dev/null || true

echo "Docker network created."

# Make helper scripts executable (scripts were copied by Packer)
chmod +x /opt/restart-coolify.sh
chmod +x /opt/stop-coolify.sh
chmod +x /opt/start-coolify.sh
chmod +x /opt/update-coolify.sh
chmod +x /opt/coolify-logs.sh
chmod +x /opt/coolify-status.sh

echo "Helper scripts made executable."

# Enable the systemd service (service file was copied by Packer)
systemctl daemon-reload
systemctl enable coolify.service

echo "Coolify systemd service enabled."

echo "Coolify installation preparation complete."
echo "Coolify will be started on first boot via the onboot script."
