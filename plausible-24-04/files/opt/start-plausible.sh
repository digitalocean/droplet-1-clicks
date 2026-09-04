#!/bin/bash
set -euo pipefail
cd /docker/plausible
docker compose up -d
systemctl start caddy
echo "Plausible started."
