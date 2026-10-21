#!/bin/sh
set -e

curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy

mkdir -p /var/log/caddy /etc/caddy
chown -R caddy:caddy /var/log/caddy

# Keep the Packer-shipped template; onboot substitutes the droplet IP.
if [ -f /etc/caddy/Caddyfile ] && [ ! -f /etc/caddy/Caddyfile.tmp ]; then
  mv /etc/caddy/Caddyfile /etc/caddy/Caddyfile.dist
fi

systemctl disable --now caddy 2>/dev/null || true
