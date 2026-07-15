

#!/bin/bash

set -e

echo "Updating Plex Media Server to the latest image..."

if [ ! -d "/opt/plex" ]; then
    echo "Error: Plex installation directory not found at /opt/plex"
    exit 1
fi

cd /opt/plex

latest=$(curl -fsSL "https://hub.docker.com/v2/repositories/plexinc/pms-docker/tags?page_size=100&ordering=-last_updated" \
  | jq -r '[.results[].name | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+-[0-9a-f]+$"))] | .[0]')

if [ -z "$latest" ] || [ "$latest" = "null" ]; then
    echo "Error: Failed to determine latest Plex version from Docker Hub"
    exit 1
fi

current=$(grep -E '^\s*image:' docker-compose.yml | sed -E 's/.*plexinc\/pms-docker://')

if [ "$current" = "$latest" ]; then
    echo "Already on latest version: ${latest}"
    exit 0
fi

echo "Updating from ${current} to ${latest}"
sed -i "s|image: plexinc/pms-docker:.*|image: plexinc/pms-docker:${latest}|" docker-compose.yml

systemctl stop plex
docker compose pull --quiet
systemctl start plex

echo "Plex Media Server updated to ${latest} and restarted successfully."
echo "Web interface: http://$(hostname -I | awk '{print $1}')"
