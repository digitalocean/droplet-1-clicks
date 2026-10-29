#!/bin/bash
set -euo pipefail

# Defense in depth: Campfire binds to 127.0.0.1:8080, but deny the port publicly
# in case a later misconfiguration publishes it on all interfaces.
ufw deny 8080/tcp comment 'Campfire app: reach via Caddy on 443' || true

echo "==> Enabling Docker..."
systemctl enable docker
systemctl start docker

echo "==> Installing Caddy..."
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy

mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy
# Caddyfile.tmp is swapped for the real Caddyfile on first boot (droplet IP).
systemctl disable --now caddy || true

# git clone the repo
cd /opt && git clone https://github.com/basecamp/once-campfire.git

# Create environment file (SECRET_KEY_BASE will be generated on first boot).
# TLS is terminated by host Caddy (shortlived IP certs / custom domain); keep SSL
# disabled inside the container and publish only to loopback.
cat > /opt/campfire.env << 'ENVEOF'
# Campfire Environment Configuration
#
# After making changes to this file, restart Campfire with:
#   /opt/restart-campfire.sh

# Rails application secret key for session encryption and security
# This will be automatically generated on first boot for security
SECRET_KEY_BASE=PLACEHOLDER_WILL_BE_REPLACED_ON_FIRST_BOOT

# Disable SSL/TLS termination in the container (Caddy on the host terminates TLS)
DISABLE_SSL=true

# Web Push notification public key (uncomment and set for push notifications)
# VAPID_PUBLIC_KEY=$YOUR_PUBLIC_KEY

# Web Push notification private key (uncomment and set for push notifications)
# VAPID_PRIVATE_KEY=$YOUR_PRIVATE_KEY
ENVEOF

# BuildKit + buildx required for COPY --chmod in once-campfire Dockerfile
# (Ubuntu docker.io does not ship a working buildx by default).
if ! docker buildx version >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq docker-buildx
fi
cd /opt/once-campfire && DOCKER_BUILDKIT=1 docker build -t campfire .

# Warm the image: loopback-only publish; public HTTPS is via Caddy after onboot.
cd /opt/once-campfire && docker run \
  --detach \
  --name campfire \
  --publish 127.0.0.1:8080:80 \
  --restart unless-stopped \
  --volume campfire:/rails/storage \
  --env-file /opt/campfire.env \
  campfire

echo "==> Setting script permissions..."
chmod +x /opt/restart-campfire.sh
chmod +x /opt/update-campfire.sh
chmod +x /opt/setup-campfire-domain.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

echo "==> Campfire setup complete."
