#!/bin/bash
set -euo pipefail

echo "Stopping Jellyfin..."
docker stop jellyfin 2>/dev/null || true
echo "Jellyfin stopped."
