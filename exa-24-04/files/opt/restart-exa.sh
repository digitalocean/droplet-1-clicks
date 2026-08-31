#!/bin/bash
set -euo pipefail
echo "Restarting Exa MCP..."
systemctl restart exa-mcp
systemctl restart caddy
sleep 2
if systemctl is-active --quiet exa-mcp; then
  echo "Exa MCP restarted successfully."
else
  echo "Failed to restart Exa MCP. Check: journalctl -u exa-mcp -xe" >&2
  exit 1
fi
