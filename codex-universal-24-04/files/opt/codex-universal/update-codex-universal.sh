#!/bin/bash
set -e

ENV_FILE="/opt/codex-universal/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found." >&2
    exit 1
fi

IMAGE_REF="$(grep -E '^IMAGE=' "$ENV_FILE" | cut -d= -f2- || true)"

if [ -z "$IMAGE_REF" ]; then
    echo "ERROR: IMAGE is not set in $ENV_FILE." >&2
    exit 1
fi

echo "Updating Codex Universal..."
echo "Current image: ${IMAGE_REF}"

cd /opt/codex-universal
docker compose pull

echo "Restarting with the updated image..."
systemctl restart codex-universal

echo "Codex Universal updated successfully."
echo ""
echo "To change the image tag, update IMAGE in $ENV_FILE, then rerun this script."
