#!/bin/bash
# Streamable HTTP entrypoint for Exa MCP (proxied publicly via Caddy).
set -euo pipefail

ENV_FILE="/etc/exa/mcp.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Exa is not configured. Run: /opt/setup-exa.sh" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [ -z "${EXA_API_KEY:-}" ]; then
  echo "EXA_API_KEY is empty in ${ENV_FILE}. Run: /opt/setup-exa.sh --force" >&2
  exit 1
fi

PKG_ROOT="$(npm root -g)/exa-mcp-server"
SHTTP=""
for candidate in \
  "${PKG_ROOT}/smithery/shttp/index.cjs" \
  "${PKG_ROOT}/.smithery/shttp/index.cjs" \
  "${PKG_ROOT}/shttp/.smithery/index.cjs"
do
  if [ -f "$candidate" ]; then
    SHTTP="$candidate"
    break
  fi
done

if [ -z "$SHTTP" ]; then
  echo "Streamable HTTP bundle not found under ${PKG_ROOT}." >&2
  echo "This 1-Click requires exa-mcp-server with smithery/shttp (e.g. 3.2.x)." >&2
  exit 1
fi

export PORT="${PORT:-8081}"
exec node "$SHTTP"
