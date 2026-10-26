#!/bin/bash
# Ensure a persistent swap file exists so OpenClaw (gateway + Docker + Control UI
# + TUI) is less likely to freeze the Droplet under memory pressure.
#
# Prefer resizing to at least 4 GB / 2 vCPU. Swap is a safety net, not a
# substitute for enough RAM.
#
# Usage: sudo /opt/ensure-openclaw-swap.sh

set -euo pipefail

SWAPFILE=/swapfile
SIZE_GB=2

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

if swapon --show 2>/dev/null | grep -q .; then
    echo "Swap already active:"
    swapon --show
    free -h
    exit 0
fi

if [ -f "$SWAPFILE" ]; then
    echo "Enabling existing ${SWAPFILE}..."
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE" >/dev/null 2>&1 || true
    swapon "$SWAPFILE"
else
    echo "Creating ${SIZE_GB}G swap at ${SWAPFILE}..."
    if ! fallocate -l "${SIZE_GB}G" "$SWAPFILE" 2>/dev/null; then
        dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SIZE_GB * 1024)) status=none
    fi
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE" >/dev/null
    swapon "$SWAPFILE"
fi

if [ -f "$SWAPFILE" ] && ! grep -qE "^${SWAPFILE}[[:space:]]" /etc/fstab 2>/dev/null; then
    echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
fi

echo "Swap ready."
swapon --show
free -h
echo
echo "If the Control UI or TUI still freezes, resize the Droplet to 4 GB / 2 vCPU+"
echo "in the DigitalOcean control panel, then reboot."
