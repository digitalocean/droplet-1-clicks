#!/bin/bash
set -euo pipefail

# Campfire Update Script
# Pulls latest once-campfire, rebuilds the image, then cuts over.
# Keeps the existing container running until the new image build succeeds
# so a failed/slow rebuild does not leave the droplet with no Campfire.

echo "Updating Campfire to latest version..."

if [ ! -d "/opt/once-campfire" ]; then
    echo "Error: Campfire installation directory not found at /opt/once-campfire"
    exit 1
fi

cd /opt/once-campfire

echo "Pulling latest code from GitHub..."
if ! git pull origin main; then
    echo "ℹ️  git pull failed; leaving running container as-is."
    exit 1
fi

echo "Rebuilding Campfire image (existing container kept until build succeeds)..."
# BuildKit + buildx required for COPY --chmod in once-campfire Dockerfile
ensure_docker_buildx() {
  if docker buildx version >/dev/null 2>&1; then
    return 0
  fi
  echo "Installing docker-buildx (required for Campfire image builds)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq docker-buildx
  docker buildx version >/dev/null 2>&1
}

if ! ensure_docker_buildx; then
  echo "❌ Error: docker-buildx is missing/broken; cannot rebuild Campfire image." >&2
  echo "   Install with: apt-get install -y docker-buildx" >&2
  exit 1
fi

if ! DOCKER_BUILDKIT=1 docker build -t campfire .; then
    echo "❌ Error: Failed to rebuild Campfire image; leaving running container as-is."
    exit 1
fi

echo "Starting Campfire with updated image..."
if [ -x "/opt/restart-campfire.sh" ] && /opt/restart-campfire.sh; then
    echo "✅ Campfire updated and restarted successfully!"
    exit 0
fi

if [ -x "/opt/restart-campfire.sh" ]; then
    echo "⚠️  /opt/restart-campfire.sh failed; attempting fallback docker run..." >&2
fi

docker stop campfire 2>/dev/null || true
docker rm campfire 2>/dev/null || true
if ! docker run \
  --detach \
  --name campfire \
  --publish 127.0.0.1:8080:80 \
  --restart unless-stopped \
  --volume campfire:/rails/storage \
  --env-file /opt/campfire.env \
  campfire; then
  echo "❌ Error: Failed to start Campfire" >&2
  exit 1
fi

# docker run -d can succeed even if the process exits immediately
for _ in $(seq 1 15); do
  if [ "$(docker inspect -f '{{.State.Running}}' campfire 2>/dev/null)" = "true" ]; then
    echo "✅ Campfire updated and restarted successfully!"
    exit 0
  fi
  sleep 1
done

echo "❌ Error: Campfire container is not running after fallback start" >&2
exit 1
