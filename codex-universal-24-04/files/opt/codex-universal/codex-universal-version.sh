#!/bin/bash

ENV_FILE="/opt/codex-universal/.env"
TEMPLATE="/opt/codex-universal/codex-universal.env"

if [ -f "$ENV_FILE" ]; then
    IMAGE="$(grep -E '^IMAGE=' "$ENV_FILE" | cut -d= -f2- || echo unknown)"
    IMAGE_DIGEST="$(grep -E '^IMAGE_DIGEST=' "$ENV_FILE" | cut -d= -f2- || echo unknown)"
    TAG="$(grep -E '^TAG=' "$ENV_FILE" | cut -d= -f2- || echo unknown)"
else
    IMAGE="$(grep -E '^IMAGE=' "$TEMPLATE" | cut -d= -f2- || echo unknown)"
    IMAGE_DIGEST="$(grep -E '^IMAGE_DIGEST=' "$TEMPLATE" | cut -d= -f2- || echo unknown)"
    TAG="$(grep -E '^TAG=' "$TEMPLATE" | cut -d= -f2- || echo unknown)"
fi

echo "Codex Universal image: ${IMAGE}"
echo "Image digest: ${IMAGE_DIGEST}"
echo "Tag label: ${TAG}"

if docker ps -a --format '{{.Names}}' | grep -qx codex-universal; then
    RUNNING_IMAGE="$(docker inspect --format='{{.Config.Image}}' codex-universal 2>/dev/null || echo unknown)"
    RUNNING_DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' codex-universal 2>/dev/null || echo unknown)"
    echo "Running container image: ${RUNNING_IMAGE}"
    echo "Running container digest: ${RUNNING_DIGEST}"
fi

echo ""
echo "Configured language runtimes:"
grep -E '^CODEX_ENV_' "${ENV_FILE:-$TEMPLATE}" 2>/dev/null || true
