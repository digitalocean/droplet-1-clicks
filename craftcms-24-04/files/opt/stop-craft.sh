#!/bin/bash
set -euo pipefail

echo "Stopping Craft CMS web stack (MySQL left running)..."
systemctl stop caddy php8.3-fpm
for s in caddy php8.3-fpm; do
  if systemctl is-active --quiet "$s"; then
    echo "ERROR: $s is still active" >&2
    exit 1
  fi
done
echo "Stopped: caddy, php8.3-fpm"
