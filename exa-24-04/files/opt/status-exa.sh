#!/bin/bash
set -euo pipefail

VERSION_FILE="/etc/exa/version"
ENV_FILE="/etc/exa/mcp.env"
CONFIGURED_MARKER="/etc/exa/.configured"

echo "Exa MCP Server status"
echo "---------------------"

if [ -f "$VERSION_FILE" ]; then
  echo "Pinned version file: $(cat "$VERSION_FILE")"
else
  echo "Pinned version file: (missing)"
fi

if command -v exa-mcp-server >/dev/null 2>&1; then
  echo "Binary: $(command -v exa-mcp-server)"
  npm list -g exa-mcp-server 2>/dev/null | head -n 2 || true
else
  echo "Binary: not found on PATH"
fi

if [ -f "$CONFIGURED_MARKER" ] && [ -f "$ENV_FILE" ]; then
  echo "API key: configured (${ENV_FILE})"
else
  echo "API key: not configured (run /opt/setup-exa.sh)"
fi

echo "Entrypoint for MCP clients: /opt/run-exa-mcp.sh"
echo "UFW: SSH only (no HTTP UI; MCP uses stdio)"
