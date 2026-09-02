#!/bin/bash
set -euo pipefail
echo "Stopping Exa MCP..."
systemctl stop exa-mcp
echo "Exa MCP stopped. Caddy left running (use: systemctl stop caddy)."
