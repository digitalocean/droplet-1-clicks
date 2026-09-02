#!/bin/bash
# Render /etc/caddy/Caddyfile from a template using public host + access token.
# Usage: /opt/render-exa-caddy.sh [ip|domain]
set -euo pipefail

MODE="${1:-}"
HOST_FILE="/etc/exa/public_host"
TOKEN_FILE="/etc/exa/access.token"
IP_TMP="/etc/caddy/Caddyfile.tmp"
DOMAIN_TMP="/etc/caddy/Caddyfile.domain.tmp"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "Missing ${TOKEN_FILE}. Run first-boot or /opt/rotate-exa-access-token.sh" >&2
  exit 1
fi
if [ ! -f "$HOST_FILE" ]; then
  echo "Missing ${HOST_FILE}" >&2
  exit 1
fi

HOST="$(tr -d '[:space:]' < "$HOST_FILE")"
TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"

if [ -z "$HOST" ] || [ -z "$TOKEN" ]; then
  echo "public_host or access.token is empty" >&2
  exit 1
fi

if [ -z "$MODE" ]; then
  if [ -f /etc/exa/caddy_template ] && [ "$(cat /etc/exa/caddy_template)" = "domain" ]; then
    MODE=domain
  else
    MODE=ip
  fi
fi

case "$MODE" in
  ip) TMP="$IP_TMP" ;;
  domain) TMP="$DOMAIN_TMP" ;;
  *)
    echo "Usage: $0 [ip|domain]" >&2
    exit 1
    ;;
esac

if [ ! -f "$TMP" ]; then
  echo "Caddy template not found: ${TMP}" >&2
  exit 1
fi

# Templates stay in place for re-render / rotate / domain changes.
sed -e "s/PLACEHOLDER_DOMAIN/${HOST}/g" \
    -e "s/PLACEHOLDER_ACCESS_TOKEN/${TOKEN}/g" \
    "$TMP" > /etc/caddy/Caddyfile

echo "$MODE" > /etc/exa/caddy_template
chmod 644 /etc/exa/caddy_template
