#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source /opt/jellyfin.env

IMAGE="${JELLYFIN_IMAGE:-jellyfin/jellyfin:${JELLYFIN_VERSION}}"

if docker ps -a --format '{{.Names}}' | grep -qx jellyfin; then
    echo "Starting existing Jellyfin container..."
    docker start jellyfin
else
    echo "Creating Jellyfin container from ${IMAGE}..."
    mkdir -p /var/lib/jellyfin/config /var/lib/jellyfin/cache /var/lib/jellyfin/media
    docker run -d \
      --name jellyfin \
      --restart unless-stopped \
      -p 127.0.0.1:8096:8096 \
      -v /var/lib/jellyfin/config:/config \
      -v /var/lib/jellyfin/cache:/cache \
      -v /var/lib/jellyfin/media:/media \
      "${IMAGE}"
fi

echo "Jellyfin is running on 127.0.0.1:8096 (proxied via Caddy)."
