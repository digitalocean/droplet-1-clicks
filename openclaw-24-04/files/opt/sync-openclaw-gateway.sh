#!/bin/bash
# Sync OPENCLAW_GATEWAY_TOKEN from /opt/openclaw.env into openclaw.json (auth + remote).
set -euo pipefail

ENV_FILE=/opt/openclaw.env
OPENCLAW_JSON=/home/openclaw/.openclaw/openclaw.json

if [ ! -f "$ENV_FILE" ] || [ ! -f "$OPENCLAW_JSON" ]; then
    echo "sync-openclaw-gateway: missing $ENV_FILE or $OPENCLAW_JSON" >&2
    exit 1
fi

read_env_kv() {
    local key="$1"
    local line val
    line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
    eval "val=${line#${key}=}"
    printf '%s' "$val"
}

GATEWAY_TOKEN=$(read_env_kv OPENCLAW_GATEWAY_TOKEN || true)
case "$GATEWAY_TOKEN" in
    '' | *'${'* | PLACEHOLDER*) echo "sync-openclaw-gateway: invalid gateway token in $ENV_FILE" >&2; exit 1 ;;
esac

DROPLET_PUBLIC_IP="$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
DROPLET_PRIVATE_IP="$(hostname -I | awk '{print $1}')"

jq --arg token "$GATEWAY_TOKEN" \
    --arg pub "$DROPLET_PUBLIC_IP" \
    --arg prv "$DROPLET_PRIVATE_IP" \
    '.gateway.auth.token = $token
     | .gateway.remote.token = $token
     | .gateway.controlUi.allowedOrigins = (
         if ($pub != "" and $pub != $prv) then
           ["https://" + $pub, "http://" + $pub, "https://" + $prv, "http://" + $prv]
         elif ($pub != "") then
           ["https://" + $pub, "http://" + $pub]
         else
           ["https://" + $prv, "http://" + $prv]
         end
       )' \
    "$OPENCLAW_JSON" >"${OPENCLAW_JSON}.tmp"
mv "${OPENCLAW_JSON}.tmp" "$OPENCLAW_JSON"
chown openclaw:openclaw "$OPENCLAW_JSON"
chmod 600 "$OPENCLAW_JSON"

exit 0
