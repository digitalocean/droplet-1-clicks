#!/bin/bash
# Write /root/exa_access_token.txt from current host + token (no rotation).
set -euo pipefail

TOKEN_FILE="/etc/exa/access.token"
CREDS_FILE="/root/exa_access_token.txt"
HOST_FILE="/etc/exa/public_host"

TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
HOST="your-droplet-ip"
if [ -f "$HOST_FILE" ]; then
  HOST="$(tr -d '[:space:]' < "$HOST_FILE")"
fi

if [ -z "$TOKEN" ]; then
  echo "access.token is empty" >&2
  exit 1
fi

umask 077
cat > "$CREDS_FILE" << EOF
Exa MCP access token (keep private)
===================================
Updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

MCP URL:
  https://${HOST}/mcp

Authorization header (required):
  Authorization: Bearer ${TOKEN}

This token gates access to the Droplet MCP endpoint.
It is NOT your Exa API key (that stays in /etc/exa/mcp.env).

Rotate anytime:
  /opt/rotate-exa-access-token.sh
EOF
chmod 600 "$CREDS_FILE"
