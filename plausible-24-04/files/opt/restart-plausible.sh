#!/bin/bash
set -euo pipefail
cd /docker/plausible
docker compose restart
systemctl restart caddy
echo "Plausible restarted."
