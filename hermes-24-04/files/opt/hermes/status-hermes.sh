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
echo "Pinned version (/opt/hermes/hermes.env):"
if [ -f /opt/hermes/hermes.env ]; then
    cur=$(grep -E '^HERMES_VERSION=' /opt/hermes/hermes.env 2>/dev/null | tail -n 1 | cut -d'=' -f2- || true)
    echo "  HERMES_VERSION: ${cur:-unset}"
else
    echo "  (no /opt/hermes/hermes.env)"
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

echo ""
echo "Update Hermes:"
echo "  Latest release:     sudo /opt/hermes/update-hermes.sh"
echo "  Specific version:   sudo /opt/hermes/update-hermes.sh <version>   # e.g. v2026.9.14"
echo "  Doctor / repair:    /opt/hermes/doctor-hermes.sh"
echo "                      /opt/hermes/doctor-hermes.sh --fix"
