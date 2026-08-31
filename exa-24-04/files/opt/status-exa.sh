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

echo ""
echo "=== systemd ==="
systemctl is-active exa-mcp >/dev/null 2>&1 && echo "exa-mcp: active" || echo "exa-mcp: inactive"
systemctl is-active caddy >/dev/null 2>&1 && echo "caddy: active" || echo "caddy: inactive"

if [ -f "$CONFIGURED_MARKER" ] && [ -f "$ENV_FILE" ]; then
  echo "API key: configured (${ENV_FILE})"
else
  echo "API key: not configured (run /opt/setup-exa.sh)"
fi

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
host="${pub:-$(hostname -I | awk '{print $1}')}"
echo ""
echo "MCP endpoint: https://${host}/mcp  (Caddy -> 127.0.0.1:8081)"
echo "Stdio entrypoint (optional): /opt/run-exa-mcp.sh"
echo "UFW: SSH + HTTP/HTTPS (app port 8081 not public)"
