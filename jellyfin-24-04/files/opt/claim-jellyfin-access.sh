#!/bin/bash
# First-SSH claim: enable public HTTPS (Caddy) only after the droplet owner logs in.
set -euo pipefail

MARKER=/var/lib/digitalocean/jellyfin_access_claimed

remove_first_login_hook() {
    if [ -f /root/.bashrc ]; then
        sed -i '/claim-jellyfin-access\.sh/d' /root/.bashrc
    fi
}

if [ -f "${MARKER}" ]; then
    remove_first_login_hook
    exit 0
fi

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"
if [ -n "$myip" ]; then
  access_url="https://${myip}"
else
  access_url="https://<your-droplet-ip>"
fi

echo "========================================================================"
echo " Claiming Jellyfin HTTPS access (first SSH login)"
echo "========================================================================"
echo ""
echo "Public HTTPS was held back until you SSH'd in so strangers cannot reach"
echo "the setup wizard. Enabling Caddy now..."
echo ""

if [ ! -f /etc/caddy/Caddyfile ]; then
    echo "ERROR: Missing /etc/caddy/Caddyfile. Re-run cloud-init/onboot or restore it." >&2
    exit 1
fi

systemctl enable --now jellyfin >/dev/null 2>&1 || systemctl start jellyfin
systemctl enable caddy
systemctl restart caddy

mkdir -p "$(dirname "${MARKER}")"
touch "${MARKER}"
remove_first_login_hook

echo "HTTPS is unlocked."
echo ""
echo "IMPORTANT NEXT STEP:"
echo "  1. Open ${access_url} in your browser"
echo "  2. Complete the Jellyfin setup wizard IMMEDIATELY to create your admin account"
echo "  3. The first person to finish the wizard gets full administrative access"
echo ""
echo "Custom domain later: sudo /opt/setup-jellyfin-domain.sh"
echo "========================================================================"
echo ""
