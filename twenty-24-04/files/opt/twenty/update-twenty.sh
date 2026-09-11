#!/bin/bash
set -e

echo "Updating Twenty CRM to latest Docker images..."

if [ ! -f /opt/twenty/docker-compose.yml ]; then
    echo "Error: Twenty installation not found at /opt/twenty"
    exit 1
fi

cd /opt/twenty

echo "Stopping Twenty CRM..."
systemctl stop twenty

echo "Pulling latest images..."
docker compose pull

echo "Starting Twenty CRM with updated images..."
systemctl start twenty

if systemctl is-active --quiet twenty; then
    echo "Twenty CRM updated and restarted successfully."
else
    echo "Error: Failed to restart Twenty CRM after update"
    exit 1
fi
