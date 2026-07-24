#!/bin/bash
set -euo pipefail

# shellcheck source=/dev/null
source /opt/jellyfin.env

CURRENT_VERSION="${JELLYFIN_VERSION:-unknown}"
TARGET_VERSION="${1:-}"
PUBLISHED_URL="${JELLYFIN_PUBLISHED_SERVER_URL:-}"

if [ -z "${TARGET_VERSION}" ]; then
    echo "Current version: ${CURRENT_VERSION}"
    echo "Usage: $0 <version>"
    echo "Example: $0 10.11.11"
    exit 1
fi

# Keep PublishedServerUrl across updates; if missing, derive like 001_onboot
if [ -z "${PUBLISHED_URL}" ]; then
    pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
      http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
    myip="${pub:-$(hostname -I | awk '{print $1}')}"
    if [ -n "${myip}" ]; then
        PUBLISHED_URL="https://${myip}"
    fi
fi

IMAGE="jellyfin/jellyfin:${TARGET_VERSION}"

echo "Updating Jellyfin from ${CURRENT_VERSION} to ${TARGET_VERSION}..."

echo "Pulling ${IMAGE}..."
docker pull "${IMAGE}"

echo "Stopping Jellyfin via systemd..."
systemctl stop jellyfin 2>/dev/null || true

{
    echo "JELLYFIN_VERSION=${TARGET_VERSION}"
    echo "JELLYFIN_IMAGE=${IMAGE}"
    if [ -n "${PUBLISHED_URL}" ]; then
        echo "JELLYFIN_PUBLISHED_SERVER_URL=${PUBLISHED_URL}"
    else
        echo "WARNING: JELLYFIN_PUBLISHED_SERVER_URL unset; container will start without it." >&2
    fi
} > /opt/jellyfin.env

echo "Starting Jellyfin ${TARGET_VERSION} via systemd..."
systemctl start jellyfin

sleep 2

if systemctl is-active --quiet jellyfin && docker ps --format '{{.Names}}' | grep -qx jellyfin; then
    if [ -f /var/lib/digitalocean/application.info ]; then
        if grep -q '^application_version=' /var/lib/digitalocean/application.info; then
            sed -i "s/^application_version=.*/application_version=\"${TARGET_VERSION}\"/" \
                /var/lib/digitalocean/application.info
        else
            echo "application_version=\"${TARGET_VERSION}\"" >> /var/lib/digitalocean/application.info
        fi
    fi
    echo "Jellyfin updated successfully to ${TARGET_VERSION}."
    if [ -n "${PUBLISHED_URL}" ]; then
        echo "PublishedServerUrl: ${PUBLISHED_URL}"
    fi
else
    echo "Error: Failed to start Jellyfin after update"
    echo "Check logs with: journalctl -u jellyfin -xe"
    echo "Container logs: docker logs jellyfin"
    exit 1
fi
