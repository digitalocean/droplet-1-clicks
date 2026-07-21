#!/bin/bash
# Update @openhands/agent-canvas from npm and restart the service

set -euo pipefail

APP_VERSION="latest"
if [ -f /opt/openhands.env ]; then
  APP_VERSION_VALUE=$(grep -E '^OPENHANDS_VERSION=' /opt/openhands.env | tail -n 1 | cut -d= -f2-)
  if [ -n "$APP_VERSION_VALUE" ]; then
    APP_VERSION="$APP_VERSION_VALUE"
  fi
fi
case "$APP_VERSION" in *'$'*) APP_VERSION="latest" ;; esac

TARGET="${1:-$APP_VERSION}"
if [ "$TARGET" = "Latest" ] || [ "$TARGET" = "latest" ]; then
  TARGET="latest"
fi

echo "Updating OpenHands Agent Canvas (target: ${TARGET})..."
systemctl stop openhands

if [ "$TARGET" = "latest" ]; then
  npm install -g @openhands/agent-canvas@latest
else
  npm install -g "@openhands/agent-canvas@${TARGET}"
fi

CANVAS_BIN="$(command -v agent-canvas)"
if [ -n "$CANVAS_BIN" ]; then
  ln -sfn "$CANVAS_BIN" /usr/local/bin/agent-canvas
fi

INSTALLED_VERSION=$(npm list -g @openhands/agent-canvas --depth=0 2>/dev/null \
  | grep '@openhands/agent-canvas@' | sed 's/.*@openhands\/agent-canvas@//' | sed 's/ .*//' || true)

if [ -n "$INSTALLED_VERSION" ] && [ -f /opt/openhands.env ]; then
  sed -i "s/^OPENHANDS_VERSION=.*/OPENHANDS_VERSION=${INSTALLED_VERSION}/" /opt/openhands.env
fi

systemctl start openhands
sleep 2

if systemctl is-active --quiet openhands; then
  echo "OpenHands updated and restarted successfully."
  echo "Version: ${INSTALLED_VERSION:-unknown}"
else
  echo "Update installed but service failed to start. Check: journalctl -u openhands -xe"
  exit 1
fi
