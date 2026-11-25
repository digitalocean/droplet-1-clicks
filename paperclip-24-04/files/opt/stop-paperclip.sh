#!/bin/bash
set -euo pipefail
echo "Stopping Paperclip..."
systemctl stop paperclip
echo "Paperclip stopped. Caddy left running (stop with: systemctl stop caddy)."
