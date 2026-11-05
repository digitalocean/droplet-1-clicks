#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

PORT=3773
BIND_IP=127.0.0.1

read -rp "Enter the domain you pointed at this droplet (e.g. t3.example.com): " DOMAIN
if ! printf '%s' "$DOMAIN" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$'; then
  echo "Domain must be a hostname like t3.example.com." >&2
  exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL
if [ -n "$EMAIL" ] && ! printf '%s' "$EMAIL" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
  echo "Email must be a simple address like admin@example.com." >&2
  exit 1
fi

cat > /etc/caddy/Caddyfile << CADDYEOC
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy ${BIND_IP}:${PORT}
    header X-DO-MARKETPLACE "t3code"
}
CADDYEOC

if [ -n "$EMAIL" ]; then
  sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
fi

systemctl enable caddy
systemctl restart caddy

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "Ensure the DNS A record for ${DOMAIN} points at this droplet."
echo "Create a new pairing link for that hostname:"
echo "  /opt/create-t3code-pairing.sh https://${DOMAIN}"
