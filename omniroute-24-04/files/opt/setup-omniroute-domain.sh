#!/bin/bash
set -euo pipefail

PORT=20128
BIND_IP=127.0.0.1
ENV_FILE=/opt/omniroute/.env

read -rp "Enter the domain you pointed at this droplet (e.g. omniroute.example.com): " DOMAIN
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
    header X-DO-MARKETPLACE "omniroute"
}
CADDYEOC
  if [ -n "$EMAIL" ]; then
    sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
  fi
}

# Keep OmniRoute public URLs in sync with the custom domain
if [ -f "$ENV_FILE" ]; then
  for key in NEXT_PUBLIC_BASE_URL OMNIROUTE_PUBLIC_BASE_URL LIVE_WS_ALLOWED_ORIGINS; do
    if grep -q "^${key}=" "$ENV_FILE"; then
      sed -i "s|^${key}=.*|${key}=https://${DOMAIN}|" "$ENV_FILE"
    else
      echo "${key}=https://${DOMAIN}" >> "$ENV_FILE"
    fi
  done
fi

systemctl enable caddy
systemctl restart caddy
systemctl restart omniroute

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "Ensure DNS A record for ${DOMAIN} points at this droplet and ports 80/443 are open."
