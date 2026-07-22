#!/bin/bash

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"
if [ -n "$myip" ]; then
  access_url="https://${myip}"
else
  access_url="https://<your-droplet-ip>"
fi

echo "=== Jellyfin systemd status ==="
systemctl status jellyfin --no-pager || true

echo ""
echo "=== Jellyfin container ==="
docker ps -a --filter name=^jellyfin$ --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}' || true

echo ""
echo "=== Version ==="
# shellcheck source=/dev/null
. /var/lib/digitalocean/application.info 2>/dev/null || true
echo "Image tag (application.info): ${application_version:-unknown}"
if [ -f /opt/jellyfin.env ]; then
    # shellcheck source=/dev/null
    source /opt/jellyfin.env
    echo "Configured image: ${JELLYFIN_IMAGE:-jellyfin/jellyfin:${JELLYFIN_VERSION}}"
fi

echo ""
echo "=== Access URL ==="
echo "${access_url} (proxied via Caddy with TLS)"
echo "http://127.0.0.1:8096 (localhost only — not publicly exposed)"
