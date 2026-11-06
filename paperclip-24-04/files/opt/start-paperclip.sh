#!/bin/bash
set -euo pipefail
echo "Starting Paperclip..."
systemctl start postgresql || true
systemctl start paperclip
systemctl start caddy
sleep 5
if systemctl is-active --quiet paperclip; then
  echo "Paperclip started successfully (UI via Caddy on ports 80/443)."
else
  echo "Failed to start Paperclip. Check: journalctl -u paperclip -xe" >&2
  exit 1
fi
