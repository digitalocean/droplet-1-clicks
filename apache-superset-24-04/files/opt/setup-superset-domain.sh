#!/bin/bash
set -euo pipefail

TMPL=/etc/caddy/Caddyfile.domain.tmpl
if [ ! -f "$TMPL" ]; then
  echo "Missing ${TMPL}" >&2
  exit 1
fi

read -r -p "Enter the domain you pointed at this droplet (e.g. bi.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi

read -r -p "Enter an email for Let's Encrypt notifications (optional): " EMAIL

cp "$TMPL" /etc/caddy/Caddyfile
sed -i "s/PLACEHOLDER_DOMAIN/${DOMAIN}/" /etc/caddy/Caddyfile

if [ -n "${EMAIL}" ]; then
  sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
fi

systemctl enable caddy
systemctl restart caddy
systemctl restart superset

echo "Caddy is now proxying https://${DOMAIN} to localhost:8088."
echo "Ensure DNS for ${DOMAIN} points to this Droplet before browsing."
