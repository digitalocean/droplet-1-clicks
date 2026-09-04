#!/bin/bash
set -euo pipefail
echo "=== Caddy ==="
systemctl --no-pager --full status caddy || true
echo
echo "=== Docker Compose ==="
cd /docker/plausible
docker compose ps
