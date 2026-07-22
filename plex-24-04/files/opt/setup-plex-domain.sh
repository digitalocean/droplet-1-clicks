#!/bin/bash
set -euo pipefail

CLAIMED_MARKER=/opt/plex/.claimed
DOMAIN_TMP=/etc/caddy/Caddyfile.domain.tmp

if [ ! -f "${CLAIMED_MARKER}" ]; then
    echo "Claim this Plex server before configuring a custom domain."
    echo "  sudo /opt/claim-plex.sh claim-XXXXXXXX"
    echo "  # or claim via SSH tunnel, then: sudo /opt/enable-plex-proxy.sh"
    exit 1
fi

if [ ! -f "${DOMAIN_TMP}" ]; then
    echo "Error: ${DOMAIN_TMP} not found"
    exit 1
fi

read -rp "Enter the domain you pointed at this droplet (e.g. plex.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

sed "s/PLACEHOLDER_DOMAIN/${DOMAIN}/" "${DOMAIN_TMP}" > /etc/caddy/Caddyfile

if [ -n "$EMAIL" ]; then
    sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
fi

# Advertise the direct Plex port (TLS terminates on Caddy :443, not :32400)
if [ -f /opt/plex/.env ]; then
    sed -i "s|^ADVERTISE_IP=.*|ADVERTISE_IP=http://${DOMAIN}:32400/|" /opt/plex/.env
else
    echo "ADVERTISE_IP=http://${DOMAIN}:32400/" > /opt/plex/.env
fi

systemctl enable caddy
systemctl restart caddy
systemctl restart plex

echo "Caddy is now proxying https://${DOMAIN} to 127.0.0.1:32400."
echo "SSL certificate will be provisioned automatically via Let's Encrypt."
