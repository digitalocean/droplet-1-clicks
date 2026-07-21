#!/bin/bash
set -euo pipefail

PORT=8000
BIND_IP=127.0.0.1

read -rp "Enter the domain you pointed at this droplet (e.g. canvas.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
  echo "Domain cannot be empty."
  exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

{
  cat > /etc/caddy/Caddyfile << CADDYEOC
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy ${BIND_IP}:${PORT}
    header X-DO-MARKETPLACE "openhands"
}
CADDYEOC
  if [ -n "$EMAIL" ]; then
    # Prepend email directive for Let's Encrypt account binding
    sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
  fi
}

systemctl enable caddy
systemctl restart caddy
systemctl restart openhands

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "Ensure DNS A record for ${DOMAIN} points at this droplet and ports 80/443 are open."
