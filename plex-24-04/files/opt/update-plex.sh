#!/bin/bash

echo "Updating Plex Media Server to the latest image..."

if [ ! -d "/opt/plex" ]; then
    echo "Error: Plex installation directory not found at /opt/plex"
    exit 1
fi

cd /opt/plex

systemctl stop plex

docker compose pull

if [ $? -eq 0 ]; then
    systemctl start plex
    echo "Plex Media Server updated and restarted successfully."
else
    echo "Error: Failed to pull updated Plex image"
    exit 1
fi
