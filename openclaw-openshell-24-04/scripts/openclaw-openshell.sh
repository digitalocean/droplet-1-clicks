#!/bin/sh
# OpenClaw + OpenShell 1-Click: install Docker, OpenShell, OpenClaw, create sandbox, Caddy.

APP_VERSION="${application_version:-Latest}"

# Open required ports
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

systemctl enable fail2ban
systemctl restart fail2ban

# Install Node.js 22 (required for OpenClaw)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install Caddy (reverse proxy with automatic TLS) - same as OpenClaw 1-Click
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
touch /var/log/caddy/access.json
chown caddy:caddy /var/log/caddy/access.json

# Install Docker (required for OpenShell sandbox)
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

# Install OpenShell CLI (per instructions: curl | sh)
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh
# Ensure root's bashrc sources OpenShell env so non-interactive shells have openshell on PATH
grep -q '\. "/root/.local/bin/env"' /root/.bashrc 2>/dev/null || echo '. "/root/.local/bin/env"' >> /root/.bashrc

# Create openclaw user and install OpenClaw (needed for sandbox --from openclaw)
useradd -m -s /bin/bash openclaw || true
usermod -aG docker openclaw || true

. "/root/.local/bin/env" 2>/dev/null || true
# nohup + </dev/null so create runs in background; sandbox shell gets EOF and exits, packer script continues
nohup openshell sandbox create --name openclaw-sandbox --forward 18789 --from openclaw </dev/null >/var/log/openclaw-sandbox-create.log 2>&1 &
sleep 180
