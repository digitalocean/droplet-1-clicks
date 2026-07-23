#!/bin/bash
# Stdio entrypoint for MCP clients. Loads EXA_API_KEY and execs the server.
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

exec exa-mcp-server "$@"
