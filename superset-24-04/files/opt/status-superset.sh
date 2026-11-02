#!/bin/bash
set -euo pipefail

echo "=== systemd ==="
systemctl status superset --no-pager || true
echo
echo "=== container ==="
docker ps -a --filter name=^/superset$ || true
echo
if [[ -f /var/lib/superset/setup-complete ]]; then
  echo "First-boot setup: complete"
else
  echo "First-boot setup: not complete (admin password stays hidden)"
fi
echo
if curl -fsS --max-time 5 http://127.0.0.1:8088/health; then
  echo
  echo "Health check passed (http://127.0.0.1:8088/health)."
else
  echo "Health check failed."
  exit 1
fi
