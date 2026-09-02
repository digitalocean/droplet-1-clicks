#!/bin/bash
# Generate or rotate the Droplet MCP access token (Bearer), then reload Caddy.
set -euo pipefail

TOKEN_FILE="/etc/exa/access.token"

mkdir -p /etc/exa
chmod 700 /etc/exa

TOKEN="$(openssl rand -hex 32)"
umask 077
printf '%s\n' "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

/opt/write-exa-access-creds.sh

if [ -f /etc/caddy/Caddyfile.tmp ] || [ -f /etc/caddy/Caddyfile.domain.tmp ]; then
  /opt/render-exa-caddy.sh
  systemctl reload caddy 2>/dev/null || systemctl restart caddy 2>/dev/null || true
fi

echo "New access token written to ${TOKEN_FILE} and /root/exa_access_token.txt"
echo "Clients must send: Authorization: Bearer ${TOKEN}"
