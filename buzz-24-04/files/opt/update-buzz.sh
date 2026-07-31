#!/bin/bash
set -euo pipefail

ENV_FILE=/opt/buzz/.env
TARGET="${1:-}"

if [ -n "$TARGET" ]; then
  case "$TARGET" in
    *:*) IMAGE="$TARGET" ;;
    *) IMAGE="ghcr.io/block/buzz:${TARGET#v}" ;;
  esac
  echo "Pinning BUZZ_IMAGE=${IMAGE}"
  sed -i "s|^BUZZ_IMAGE=.*|BUZZ_IMAGE=${IMAGE}|" "$ENV_FILE"
fi

echo "Updating Buzz images and restarting stack..."
/opt/buzz/run.sh upgrade
echo "Done. Check status with: /opt/status-buzz.sh"
