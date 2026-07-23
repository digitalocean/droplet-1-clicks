#!/bin/bash
# First-login (or manual) setup: store Exa API key for local stdio MCP.

set -euo pipefail

CONFIGURED_MARKER="/etc/exa/.configured"
ENV_FILE="/etc/exa/mcp.env"

remove_bashrc_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '\|/opt/setup-exa.sh|d' /root/.bashrc
  fi
}

if [ -f "$CONFIGURED_MARKER" ] && [ "${1:-}" != "--force" ]; then
  remove_bashrc_hook
  exit 0
fi

echo ""
echo "================================================================"
echo "       Welcome to the Exa MCP Server 1-Click Droplet!"
echo "================================================================"
echo ""
echo "Exa MCP runs over stdio and is started by your MCP client"
echo "(for example Cursor, Claude Desktop, or Claude Code)."
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

echo ""
echo "Exa API key saved to ${ENV_FILE}."
echo ""
echo "Point your MCP client at: /opt/run-exa-mcp.sh"
echo "Example (Cursor ~/.cursor/mcp.json):"
echo '  {"mcpServers":{"exa":{"command":"/opt/run-exa-mcp.sh"}}}'
echo ""
echo "Status:  /opt/status-exa.sh"
echo "Update:  /opt/update-exa.sh"
echo ""
