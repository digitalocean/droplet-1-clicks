#!/bin/bash
set -euo pipefail

DOMAIN_TMP=/etc/caddy/Caddyfile.domain.tmp
HOST_FILE=/etc/exa/public_host

if [ ! -f "${DOMAIN_TMP}" ]; then
  echo "Error: ${DOMAIN_TMP} not found" >&2
  exit 1
fi
if [ ! -f /etc/exa/access.token ]; then
  echo "Missing access token. Run: /opt/rotate-exa-access-token.sh" >&2
  exit 1
fi

read -rp "Enter the domain you pointed at this droplet (e.g. mcp.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

printf '%s\n' "$DOMAIN" > "$HOST_FILE"
chmod 644 "$HOST_FILE"

/opt/render-exa-caddy.sh domain

if [ -n "${EMAIL}" ]; then
  sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
fi

/opt/write-exa-access-creds.sh

systemctl enable caddy
systemctl restart caddy

echo "Caddy is now proxying https://${DOMAIN} (Bearer auth required)."
echo "MCP endpoint: https://${DOMAIN}/mcp"
echo "Access token: /root/exa_access_token.txt"
echo "Ensure DNS A record for ${DOMAIN} points at this droplet and ports 80/443 are open."
