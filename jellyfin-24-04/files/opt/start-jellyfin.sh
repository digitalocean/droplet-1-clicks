#!/bin/bash
set -euo pipefail

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"
if [ -n "$myip" ]; then
  access_url="https://${myip}"
else
  access_url="https://<your-droplet-ip>"
fi

echo "Starting Jellyfin via systemd..."
systemctl start jellyfin

sleep 1
if systemctl is-active --quiet jellyfin; then
    echo "Jellyfin started successfully."
    if [ -f /var/lib/digitalocean/jellyfin_access_claimed ]; then
        echo "Access via ${access_url}"
    else
        echo "HTTPS is not public yet. SSH claim runs /opt/claim-jellyfin-access.sh on first login."
    fi
else
    echo "Error: Failed to start Jellyfin"
    echo "Check logs with: journalctl -u jellyfin -xe"
    exit 1
fi
