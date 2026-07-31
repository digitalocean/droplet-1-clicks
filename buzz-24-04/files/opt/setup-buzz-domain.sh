#!/bin/bash
set -euo pipefail

PORT=3000
BIND_IP=127.0.0.1
ENV_FILE=/opt/buzz/.env
DOMAIN_TMP=/etc/caddy/Caddyfile.domain.tmp

if [ ! -f "${DOMAIN_TMP}" ]; then
  echo "Error: ${DOMAIN_TMP} not found"
  exit 1
fi

read -rp "Enter the domain you pointed at this droplet (e.g. buzz.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

sed "s/PLACEHOLDER_DOMAIN/${DOMAIN}/" "${DOMAIN_TMP}" > /etc/caddy/Caddyfile

if [ -n "$EMAIL" ]; then
  sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
fi

# Keep relay public URLs in sync with the custom domain.
sed -i "s|^BUZZ_DOMAIN=.*|BUZZ_DOMAIN=${DOMAIN}|" "$ENV_FILE"
sed -i "s|^RELAY_URL=.*|RELAY_URL=wss://${DOMAIN}|" "$ENV_FILE"
sed -i "s|^BUZZ_MEDIA_BASE_URL=.*|BUZZ_MEDIA_BASE_URL=https://${DOMAIN}/media|" "$ENV_FILE"
sed -i "s|^BUZZ_MEDIA_SERVER_DOMAIN=.*|BUZZ_MEDIA_SERVER_DOMAIN=${DOMAIN}|" "$ENV_FILE"
sed -i "s|^BUZZ_CORS_ORIGINS=.*|BUZZ_CORS_ORIGINS=https://${DOMAIN}|" "$ENV_FILE"

systemctl enable caddy
systemctl restart caddy
systemctl restart buzz

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "Relay URL updated to wss://${DOMAIN}."
echo "Ensure DNS A/AAAA for ${DOMAIN} points at this droplet and ports 80/443 are open."
