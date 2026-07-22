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
    echo ""
    read -rp "Enter Jellyfin version to install (or leave blank to cancel): " TARGET_VERSION
    if [ -z "${TARGET_VERSION}" ]; then
        echo "Update cancelled."
        exit 0
    fi
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
    echo "Jellyfin updated successfully to ${TARGET_VERSION}."
else
    echo "Error: Failed to start Jellyfin after update"
    echo "Check logs with: docker logs jellyfin"
    exit 1
fi
