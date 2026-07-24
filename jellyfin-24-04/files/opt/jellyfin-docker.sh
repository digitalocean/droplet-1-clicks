#!/bin/bash
# Container lifecycle used by the jellyfin systemd unit (ExecStart/ExecStop).
# User-facing helpers should call systemctl, not this script directly.
set -euo pipefail

# shellcheck source=/dev/null
source /opt/jellyfin.env

IMAGE="${JELLYFIN_IMAGE:-jellyfin/jellyfin:${JELLYFIN_VERSION}}"
PUBLISHED_URL="${JELLYFIN_PUBLISHED_SERVER_URL:-}"

usage() {
    echo "Usage: $0 {start|stop}"
    exit 1
}

start_container() {
    if docker ps -a --format '{{.Names}}' | grep -qx jellyfin; then
        echo "Starting existing Jellyfin container..."
        docker start jellyfin
    else
        echo "Creating Jellyfin container from ${IMAGE}..."
        mkdir -p /var/lib/jellyfin/config /var/lib/jellyfin/cache /var/lib/jellyfin/media
        run_args=(
            -d
            --name jellyfin
            --restart unless-stopped
            -p 127.0.0.1:8096:8096
            -v /var/lib/jellyfin/config:/config
            -v /var/lib/jellyfin/cache:/cache
            -v /var/lib/jellyfin/media:/media
        )
        if [ -n "${PUBLISHED_URL}" ]; then
            run_args+=(-e "JELLYFIN_PublishedServerUrl=${PUBLISHED_URL}")
        fi
        docker run "${run_args[@]}" "${IMAGE}"
    fi
    echo "Jellyfin is running on 127.0.0.1:8096 (proxied via Caddy after access is claimed)."
}

stop_container() {
    echo "Stopping Jellyfin..."
    docker stop jellyfin 2>/dev/null || true
    # Remove so the next start recreates with current /opt/jellyfin.env
    # (Docker env vars like JELLYFIN_PublishedServerUrl are only applied at create time).
    docker rm jellyfin 2>/dev/null || true
    echo "Jellyfin stopped."
}

case "${1:-}" in
    start) start_container ;;
    stop) stop_container ;;
    *) usage ;;
esac
