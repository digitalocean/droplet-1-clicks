#!/bin/bash
set -euo pipefail

PORT=42617
BIND_IP=127.0.0.1

read -rp "Enter the domain you pointed at this droplet (e.g. bot.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

cat > /etc/caddy/Caddyfile << CADDYEOF
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy ${BIND_IP}:${PORT}
    header X-DO-MARKETPLACE "zeroclaw"
}
CADDYEOF

if [ -n "$EMAIL" ]; then
    sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
fi

systemctl enable caddy
systemctl restart caddy

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "SSL certificate will be provisioned automatically via Let's Encrypt."
