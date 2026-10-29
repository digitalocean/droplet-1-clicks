#!/bin/bash
set -euo pipefail

echo "Stopping and removing existing Campfire container..."
docker stop campfire 2>/dev/null || true
docker rm campfire 2>/dev/null || true

echo "Starting Campfire with updated environment..."
# Host :8080 is loopback-only; Caddy terminates TLS on :80/:443 and proxies here.
if ! (cd /opt/once-campfire && docker run \
  --detach \
  --name campfire \
  --publish 127.0.0.1:8080:80 \
  --restart unless-stopped \
  --volume campfire:/rails/storage \
  --env-file /opt/campfire.env \
  campfire); then
  echo "❌ Error: Failed to start Campfire container" >&2
  exit 1
fi

# docker run -d can succeed even if the process exits immediately
for _ in $(seq 1 15); do
  if [ "$(docker inspect -f '{{.State.Running}}' campfire 2>/dev/null)" = "true" ]; then
    echo "Campfire restarted successfully!"
    exit 0
  fi
  sleep 1
done

echo "❌ Error: Campfire container is not running after start" >&2
exit 1
