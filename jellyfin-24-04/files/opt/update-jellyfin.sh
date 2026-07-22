#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source /opt/jellyfin.env

CURRENT_VERSION="${JELLYFIN_VERSION:-unknown}"
TARGET_VERSION="${1:-}"

if [ -z "${TARGET_VERSION}" ]; then
    echo "Current version: ${CURRENT_VERSION}"
    echo "Usage: $0 <version>"
    echo "Example: $0 10.11.11"
    exit 1
fi

IMAGE="jellyfin/jellyfin:${TARGET_VERSION}"

echo "Updating Jellyfin from ${CURRENT_VERSION} to ${TARGET_VERSION}..."

echo "Pulling ${IMAGE}..."
docker pull "${IMAGE}"

echo "Stopping existing container..."
docker stop jellyfin 2>/dev/null || true
docker rm jellyfin 2>/dev/null || true

cat > /opt/jellyfin.env <<EOF
JELLYFIN_VERSION=${TARGET_VERSION}
JELLYFIN_IMAGE=${IMAGE}
EOF

echo "Starting Jellyfin ${TARGET_VERSION}..."
/opt/start-jellyfin.sh

sleep 2

if docker ps --format '{{.Names}}' | grep -qx jellyfin; then
    if [ -f /var/lib/digitalocean/application.info ]; then
        if grep -q '^application_version=' /var/lib/digitalocean/application.info; then
            sed -i "s/^application_version=.*/application_version=\"${TARGET_VERSION}\"/" \
                /var/lib/digitalocean/application.info
        else
            echo "application_version=\"${TARGET_VERSION}\"" >> /var/lib/digitalocean/application.info
        fi
    fi
    echo "Jellyfin updated successfully to ${TARGET_VERSION}."
else
    echo "Error: Failed to start Jellyfin after update"
    echo "Check logs with: docker logs jellyfin"
    exit 1
fi
