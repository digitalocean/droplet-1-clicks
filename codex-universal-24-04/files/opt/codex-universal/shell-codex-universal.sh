#!/bin/bash
set -e

if ! docker ps --format '{{.Names}}' | grep -qx codex-universal; then
    echo "Codex Universal container is not running. Starting it..."
    systemctl start codex-universal
fi

echo "Opening an interactive shell in the Codex Universal environment..."
echo "Your workspace is mounted at /workspace inside the container (/root/workspace on the host)."
echo ""
docker exec -it codex-universal bash --login
