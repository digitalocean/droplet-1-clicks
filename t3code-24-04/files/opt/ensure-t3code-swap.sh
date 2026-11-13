#!/bin/bash
# Safety net when a droplet is smaller than the recommended 4 GB.
set -euo pipefail

SWAPFILE=/swapfile
SIZE_GB=2

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
if [ "${mem_kb:-0}" -ge 3600000 ]; then
  echo "Memory is about 4 GB or more; leaving swap unchanged."
  exit 0
fi

if swapon --show 2>/dev/null | grep -q .; then
  echo "Swap already active."
  exit 0
fi

if [ ! -f "$SWAPFILE" ]; then
  echo "Creating ${SIZE_GB}G swap at ${SWAPFILE}..."
  if ! fallocate -l "${SIZE_GB}G" "$SWAPFILE" 2>/dev/null; then
    dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SIZE_GB * 1024)) status=none
  fi
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE" >/dev/null
fi

swapon "$SWAPFILE" || true
if ! grep -qE "^${SWAPFILE}[[:space:]]" /etc/fstab 2>/dev/null; then
  echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
fi
echo "Swap ready."
