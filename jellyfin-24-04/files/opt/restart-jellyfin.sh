#!/bin/bash
set -euo pipefail

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"

echo "Restarting Jellyfin..."
/opt/stop-jellyfin.sh
/opt/start-jellyfin.sh

sleep 2

if docker ps --format '{{.Names}}' | grep -qx jellyfin; then
    echo "Jellyfin restarted successfully!"
    echo "Access via https://${myip}"
else
    echo "Error: Failed to restart Jellyfin"
    echo "Check logs with: docker logs jellyfin"
    exit 1
fi
