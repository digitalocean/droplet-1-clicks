#!/bin/bash
set -euo pipefail

PORT=8081
BIND_IP=127.0.0.1

read -rp "Enter the domain you pointed at this droplet (e.g. mcp.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

{
  if [ -n "${EMAIL}" ]; then
    echo "email ${EMAIL}"
  fi
  cat << CADDYEOF
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy ${BIND_IP}:${PORT}
    header X-DO-MARKETPLACE "exa"
}
CADDYEOF
} > /etc/caddy/Caddyfile

systemctl enable caddy
systemctl restart caddy

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "MCP endpoint: https://${DOMAIN}/mcp"
echo "Ensure DNS A record for ${DOMAIN} points at this droplet and ports 80/443 are open."
