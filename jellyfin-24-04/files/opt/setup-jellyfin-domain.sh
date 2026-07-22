#!/bin/bash
set -euo pipefail

PORT=8096
BIND_IP=127.0.0.1

read -rp "Enter the domain you pointed at this droplet (e.g. media.example.com): " DOMAIN
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
    header X-DO-MARKETPLACE "jellyfin"
}
CADDYEOF
} > /etc/caddy/Caddyfile

systemctl enable caddy
systemctl restart caddy

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "SSL certificate will be provisioned automatically via Let's Encrypt."
