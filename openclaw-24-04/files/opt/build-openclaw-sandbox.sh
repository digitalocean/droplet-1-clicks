#!/bin/bash
# Build openclaw-sandbox:bookworm-slim (required when agents.defaults.sandbox.mode is "all").
set -euo pipefail

IMAGE_NAME="${OPENCLAW_SANDBOX_IMAGE:-openclaw-sandbox:bookworm-slim}"
DOCKERFILE="/opt/openclaw-sandbox/Dockerfile"
BUILD_CTX="/opt/openclaw-sandbox"

if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "Sandbox image already present: ${IMAGE_NAME}"
    exit 0
fi

if [ ! -f "$DOCKERFILE" ]; then
    echo "Missing ${DOCKERFILE}" >&2
    exit 1
fi

if ! systemctl is-active --quiet docker 2>/dev/null; then
    systemctl start docker
fi

# Use classic builder: DO 1-Click ships docker.io without buildx by default.
echo "Building sandbox image ${IMAGE_NAME}..."
DOCKER_BUILDKIT=0 docker build -t "$IMAGE_NAME" -f "$DOCKERFILE" "$BUILD_CTX"
docker image inspect "$IMAGE_NAME" >/dev/null
echo "Built ${IMAGE_NAME}"
