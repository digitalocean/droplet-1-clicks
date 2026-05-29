#!/bin/bash

echo "=== Codex Universal Status ==="
echo ""
systemctl status codex-universal --no-pager || true
echo ""
docker compose -f /opt/codex-universal/docker-compose.yml ps 2>/dev/null || true
echo ""
if docker ps --format '{{.Names}}' | grep -qx codex-universal; then
    echo "Container is running. Enter with: /opt/codex-universal/shell-codex-universal.sh"
else
    echo "Container is not running. Start with: /opt/codex-universal/start-codex-universal.sh"
fi
