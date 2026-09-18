#!/bin/bash
set -euo pipefail

read -rp "Enter the domain you pointed at this droplet (e.g. crm.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

SERVER_URL="https://${DOMAIN}"

if grep -q '^SERVER_URL=' /opt/twenty/.env; then
    sed -i "s|^SERVER_URL=.*|SERVER_URL=${SERVER_URL}|" /opt/twenty/.env
else
    echo "SERVER_URL=${SERVER_URL}" >> /opt/twenty/.env
fi

{
    cat > /etc/caddy/Caddyfile << CADDYEOC
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    reverse_proxy localhost:3000
    header X-DO-MARKETPLACE "twenty"
}
CADDYEOC
    if [ -n "$EMAIL" ]; then
        sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
    fi
}

systemctl enable caddy
systemctl restart twenty
systemctl restart caddy

echo "Twenty CRM is now available at ${SERVER_URL}"
echo "Update complete. You may need to wait a minute for SSL certificate issuance."
