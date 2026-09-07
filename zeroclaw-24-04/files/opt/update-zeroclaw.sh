#!/bin/bash

# ZeroClaw Update Script
# Downloads and installs the latest ZeroClaw release binary + web dashboard

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
WEB_DIST_SYSTEM=/usr/share/zeroclawlabs/web/dist
WEB_DIST_USER=/home/zeroclaw/.local/share/zeroclaw/web/dist

install_web_dist() {
    local src_dist=$1
    [ -f "${src_dist}/index.html" ] || return 0
    mkdir -p "$WEB_DIST_SYSTEM" "$WEB_DIST_USER"
    cp -a "${src_dist}/." "$WEB_DIST_SYSTEM/"
    cp -a "${src_dist}/." "$WEB_DIST_USER/"
    chown -R zeroclaw:zeroclaw /home/zeroclaw/.local
    # Drop stale hashed assets from prior builds
    (
        cd "$WEB_DIST_SYSTEM" || exit 0
        find . -type f | while IFS= read -r f; do
            [ -f "${src_dist}/$f" ] || rm -f "$f"
        done
        find . -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
    )
    (
        cd "$WEB_DIST_USER" || exit 0
        find . -type f | while IFS= read -r f; do
            [ -f "${src_dist}/$f" ] || rm -f "$f"
        done
        find . -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
    )
    echo "Web dashboard installed to ${WEB_DIST_SYSTEM} and ${WEB_DIST_USER}"
}

echo "Stopping ZeroClaw service..."
systemctl stop zeroclaw

echo "Downloading latest ZeroClaw for ${TARGET}..."
cd /tmp
rm -rf "/tmp/zeroclaw-update-${TARGET}"
mkdir -p "/tmp/zeroclaw-update-${TARGET}"
cd "/tmp/zeroclaw-update-${TARGET}"
curl -fsSLO "$LATEST_URL"
tar xzf "zeroclaw-${TARGET}.tar.gz"
install -m 0755 zeroclaw /usr/local/bin/zeroclaw
if [ -f zerocode ]; then
    install -m 0755 zerocode /usr/local/bin/zerocode
fi
install_web_dist web/dist
rm -rf "/tmp/zeroclaw-update-${TARGET}"

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

echo "Update complete."
