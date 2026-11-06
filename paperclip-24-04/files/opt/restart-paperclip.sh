#!/bin/bash
set -euo pipefail
echo "Restarting Paperclip..."
systemctl start postgresql || true
systemctl restart paperclip
systemctl restart caddy
sleep 5
/opt/status-paperclip.sh
