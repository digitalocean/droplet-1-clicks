#!/bin/bash

# ZeroClaw Update Script
# Downloads and installs the latest ZeroClaw release binary

set -euo pipefail

CURRENT_VERSION=$(/usr/local/bin/zeroclaw --version 2>/dev/null | head -1 || echo "unknown")
echo "Current version: ${CURRENT_VERSION}"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  TARGET="x86_64-unknown-linux-gnu" ;;
    aarch64) TARGET="aarch64-unknown-linux-gnu" ;;
    armv7l)  TARGET="armv7-unknown-linux-gnueabihf" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

LATEST_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/latest/download/zeroclaw-${TARGET}.tar.gz"

echo "Stopping ZeroClaw service..."
systemctl stop zeroclaw

echo "Downloading latest ZeroClaw for ${TARGET}..."
cd /tmp
curl -fsSLO "$LATEST_URL"

if [ $? -eq 0 ]; then
    tar xzf "zeroclaw-${TARGET}.tar.gz"
    install -m 0755 zeroclaw /usr/local/bin/zeroclaw
    rm -f "zeroclaw-${TARGET}.tar.gz" zeroclaw

    NEW_VERSION=$(/usr/local/bin/zeroclaw --version 2>/dev/null | head -1 || echo "unknown")

    echo "Starting ZeroClaw..."
    systemctl start zeroclaw

    sleep 2

    if systemctl is-active --quiet zeroclaw; then
        echo "ZeroClaw updated and restarted successfully!"
        echo "Version: ${NEW_VERSION}"
    else
        echo "Error: Failed to restart ZeroClaw after update"
        echo "Check logs: journalctl -u zeroclaw -xe"
        exit 1
    fi
else
    echo "Error: Failed to download ZeroClaw"
    systemctl start zeroclaw
    exit 1
fi

echo "Update complete."
