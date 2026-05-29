#!/bin/bash
set -euo pipefail

echo "=== Hermes Agent Status ==="
echo ""

echo "CLI:"
if [ -x /home/hermes/.local/bin/hermes ]; then
    /opt/hermes/hermes-cli.sh --version 2>/dev/null || true
else
    echo "Hermes CLI is not installed."
fi

echo ""
echo "Config:"
echo "  Home: /home/hermes/.hermes"
echo "  Config: /home/hermes/.hermes/config.yaml"
echo "  Env: /home/hermes/.hermes/.env"
echo "  Workspace: /home/hermes/workspace"

echo ""
echo "Gateway:"
/opt/hermes/hermes-cli.sh gateway status 2>/dev/null || echo "Gateway is not configured or not running."
