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

# Keep Jellyfin's advertised URL in sync with the custom domain
if [ -f /opt/jellyfin.env ]; then
    if grep -q '^JELLYFIN_PUBLISHED_SERVER_URL=' /opt/jellyfin.env; then
        sed -i "s|^JELLYFIN_PUBLISHED_SERVER_URL=.*|JELLYFIN_PUBLISHED_SERVER_URL=https://${DOMAIN}|" /opt/jellyfin.env
    else
        echo "JELLYFIN_PUBLISHED_SERVER_URL=https://${DOMAIN}" >> /opt/jellyfin.env
    fi
fi

# Recreate the container so the new PublishedServerUrl is applied
# (systemctl stop removes the container via jellyfin-docker.sh)
systemctl stop jellyfin 2>/dev/null || true
systemctl start jellyfin

# Domain setup implies the owner is present; unlock HTTPS if not yet claimed
mkdir -p /var/lib/digitalocean
touch /var/lib/digitalocean/jellyfin_access_claimed
if [ -f /root/.bashrc ]; then
    sed -i '/claim-jellyfin-access\.sh/d' /root/.bashrc
fi

systemctl enable caddy
systemctl restart caddy

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "JELLYFIN_PublishedServerUrl set to https://${DOMAIN}."
echo "SSL certificate will be provisioned automatically via Let's Encrypt."
