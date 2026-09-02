#!/bin/bash
# First-login (or manual) setup: store Exa API key and start HTTP MCP behind Caddy.

set -euo pipefail

CONFIGURED_MARKER="/etc/exa/.configured"
ENV_FILE="/etc/exa/mcp.env"
TOKEN_FILE="/etc/exa/access.token"
HOST_FILE="/etc/exa/public_host"

remove_bashrc_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '\|/opt/setup-exa.sh|d' /root/.bashrc
  fi
}

droplet_ip() {
  if [ -f "$HOST_FILE" ]; then
    tr -d '[:space:]' < "$HOST_FILE"
    return
  fi
  pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
  echo "${pub:-$(hostname -I | awk '{print $1}')}"
}

if [ -f "$CONFIGURED_MARKER" ] && [ "${1:-}" != "--force" ]; then
  remove_bashrc_hook
  exit 0
fi

HOST="$(droplet_ip)"
TOKEN=""
if [ -f "$TOKEN_FILE" ]; then
  TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
fi

echo ""
echo "================================================================"
echo "       Welcome to the Exa MCP Server 1-Click Droplet!"
echo "================================================================"
echo ""
echo "Exa MCP is served over HTTPS (Caddy + shortlived TLS) at:"
echo "  https://${HOST}/mcp"
if [ -n "$TOKEN" ]; then
  echo ""
  echo "Droplet access token (Bearer) is required on every request."
  echo "  See: /root/exa_access_token.txt"
fi
echo ""
echo "To get started, you need an API key from Exa:"
echo "  https://dashboard.exa.ai/api-keys"
echo ""
echo "Press Enter to skip for now (you can re-run: /opt/setup-exa.sh)."
echo ""

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Please enter your Exa API Key: " EXA_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -z "$EXA_KEY" ]; then
  remove_bashrc_hook
  echo ""
  echo "Setup skipped. Configure later with: /opt/setup-exa.sh"
  echo ""
  exit 0
fi

mkdir -p /etc/exa
chmod 700 /etc/exa
umask 077
printf 'EXA_API_KEY=%q\n' "$EXA_KEY" > "$ENV_FILE"
chmod 600 "$ENV_FILE"
touch "$CONFIGURED_MARKER"
chmod 644 "$CONFIGURED_MARKER"
remove_bashrc_hook

systemctl enable exa-mcp
systemctl restart exa-mcp
systemctl restart caddy || true

TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE" 2>/dev/null || true)"
echo ""
echo "Exa API key saved to ${ENV_FILE}."
echo "Exa MCP is running behind Caddy with TLS + Bearer access token."
echo ""
echo "Remote MCP URL: https://${HOST}/mcp"
if [ -n "$TOKEN" ]; then
  echo "Authorization: Bearer ${TOKEN}"
  echo ""
  echo "Example (Cursor ~/.cursor/mcp.json):"
  cat <<EOF
  {
    "mcpServers": {
      "exa": {
        "url": "https://${HOST}/mcp",
        "headers": {
          "Authorization": "Bearer ${TOKEN}"
        }
      }
    }
  }
EOF
fi
echo ""
echo "Token file: /root/exa_access_token.txt"
echo "Rotate token: /opt/rotate-exa-access-token.sh"
echo "Optional local stdio entrypoint: /opt/run-exa-mcp.sh"
echo "Status:  /opt/status-exa.sh"
echo "Update:  /opt/update-exa.sh"
echo "Domain:  /opt/setup-exa-domain.sh"
echo ""
