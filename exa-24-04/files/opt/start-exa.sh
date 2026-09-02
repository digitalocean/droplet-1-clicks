#!/bin/bash
set -euo pipefail
echo "Starting Exa MCP..."
systemctl start exa-mcp
systemctl start caddy
sleep 2
if systemctl is-active --quiet exa-mcp; then
  echo "Exa MCP started successfully."
else
  echo "Failed to start Exa MCP. Check: journalctl -u exa-mcp -xe" >&2
  exit 1
fi
