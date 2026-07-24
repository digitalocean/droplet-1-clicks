#!/bin/bash
set -euo pipefail

echo "Stopping Jellyfin via systemd..."
systemctl stop jellyfin
echo "Jellyfin stopped."
