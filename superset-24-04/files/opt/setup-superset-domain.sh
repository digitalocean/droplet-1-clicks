#!/bin/bash
set -euo pipefail

TMPL=/etc/caddy/Caddyfile.domain.tmpl
if [[ ! -f "$TMPL" ]]; then
  echo "Missing ${TMPL}" >&2
  exit 1
fi

read -rp "Enter the domain you pointed at this droplet (e.g. superset.example.com): " DOMAIN
if [[ -z "${DOMAIN}" ]]; then
  echo "Domain cannot be empty."
  exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

cp "$TMPL" /etc/caddy/Caddyfile
sed -i "s/PLACEHOLDER_DOMAIN/${DOMAIN}/" /etc/caddy/Caddyfile

if [[ -n "${EMAIL}" ]]; then
  sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
fi

systemctl enable caddy
systemctl restart caddy

echo "Caddy is now proxying https://${DOMAIN} to 127.0.0.1:8088."
echo "Ensure the DNS A record for ${DOMAIN} points at this droplet and ports 80 and 443 are open."
