#!/bin/bash
set -euo pipefail

PORT=18789
BIND_IP=127.0.0.1
OPENCLAW_JSON=/home/openclaw/.openclaw/openclaw.json

read -rp "Enter the domain you pointed at this droplet (e.g. bot.example.com): " DOMAIN
if [ -z "${DOMAIN}" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

# Normalize: accept bare host or full URL; Control UI Origin is scheme+host.
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"
DOMAIN="${DOMAIN%%:*}"
if [ -z "${DOMAIN}" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

read -rp "Enter an email for Let's Encrypt notifications (optional): " EMAIL

if grep -q '^OPENCLAW_GATEWAY_BIND=' /opt/openclaw.env; then
    sed -i "s/^OPENCLAW_GATEWAY_BIND=.*/OPENCLAW_GATEWAY_BIND=${BIND_IP}/" /opt/openclaw.env
else
    echo "OPENCLAW_GATEWAY_BIND=${BIND_IP}" >> /opt/openclaw.env
fi

{
    cat > /etc/caddy/Caddyfile << CADDYEOC
${DOMAIN} {
    tls {
        issuer acme {
            dir https://acme-v02.api.letsencrypt.org/directory
            profile shortlived
        }
    }
    # Keep Caddy's X-Forwarded-* (do not strip) so pairing stays remote-required.
    # gateway.trustedProxies must include this proxy address (see sync-openclaw-gateway.sh).
    reverse_proxy ${BIND_IP}:${PORT}
}
CADDYEOC
    if [ -n "$EMAIL" ]; then
        # Prepend email directive for Let's Encrypt account binding
        sed -i "1iemail ${EMAIL}" /etc/caddy/Caddyfile
    fi
}

# Gateway rejects Control UI connections whose Origin is not listed.
# Sync refreshes tokens / trustedProxies / IP origins (and merges any prior custom
# domains). Then replace allowedOrigins with droplet IPs + this domain only so
# re-running with a new host drops stale https://old-domain entries. Later sync
# merges and will keep this domain.
if [ -f "$OPENCLAW_JSON" ]; then
    if [ -x /opt/sync-openclaw-gateway.sh ]; then
        /opt/sync-openclaw-gateway.sh
    fi
    DROPLET_PUBLIC_IP="$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
        http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
    DROPLET_PRIVATE_IP="$(hostname -I | awk '{print $1}')"
    jq --arg origin "https://${DOMAIN}" \
        --arg pub "$DROPLET_PUBLIC_IP" \
        --arg prv "$DROPLET_PRIVATE_IP" \
        '.gateway = (if (.gateway | type) == "object" then .gateway else {} end)
         | .gateway.controlUi = (if (.gateway.controlUi | type) == "object" then .gateway.controlUi else {} end)
         | .gateway.controlUi.allowedOrigins = (
             (
               (if ($pub != "" and $pub != $prv) then
                 ["https://" + $pub, "http://" + $pub, "https://" + $prv, "http://" + $prv]
               elif ($pub != "") then
                 ["https://" + $pub, "http://" + $pub]
               elif ($prv != "") then
                 ["https://" + $prv, "http://" + $prv]
               else
                 []
               end)
               + [$origin]
             ) | unique
           )' \
        "$OPENCLAW_JSON" >"${OPENCLAW_JSON}.tmp"
    mv "${OPENCLAW_JSON}.tmp" "$OPENCLAW_JSON"
    chown openclaw:openclaw "$OPENCLAW_JSON"
    chmod 600 "$OPENCLAW_JSON"
    echo "gateway.controlUi.allowedOrigins -> $(jq -c '.gateway.controlUi.allowedOrigins' "$OPENCLAW_JSON")"
else
    echo "Warning: missing $OPENCLAW_JSON — skipped allowedOrigins update." >&2
    echo "After OpenClaw config exists, re-run this script or add https://${DOMAIN} to gateway.controlUi.allowedOrigins." >&2
fi

systemctl enable caddy
systemctl restart caddy
systemctl restart openclaw

echo "Caddy is now proxying https://${DOMAIN} to ${BIND_IP}:${PORT}."
echo "Open the Control UI at https://${DOMAIN}/ (Origin must match allowedOrigins)."
echo "Gateway bind set to ${BIND_IP}. You can adjust /opt/openclaw.env and rerun this script if needed."
