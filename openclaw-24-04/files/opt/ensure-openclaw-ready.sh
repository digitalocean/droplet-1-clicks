#!/bin/bash
# Fix gateway tokens / trustedProxies in openclaw.json, repair Caddy proxy target,
# and ensure sandbox image exists (run as root on a live droplet).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

chmod +x /opt/sync-openclaw-gateway.sh /opt/build-openclaw-sandbox.sh

if [ ! -f /home/openclaw/.openclaw/openclaw.json ]; then
    echo "Missing /home/openclaw/.openclaw/openclaw.json — run setup or apply-inference-from-env first." >&2
    exit 1
fi

/opt/sync-openclaw-gateway.sh
/opt/build-openclaw-sandbox.sh

chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
chmod 600 /home/openclaw/.openclaw/openclaw.json

# OpenClaw 2.0 needs trustedProxies for Caddy→loopback. Keep X-Forwarded-* so
# Control UI device pairing stays required (stripping them auto-approves pairing).
repair_caddy_proxy_attribution() {
    local caddyfile=/etc/caddy/Caddyfile
    [ -f "$caddyfile" ] || return 0

    # Desired: reverse_proxy 127.0.0.1:18789 with no header_up strip/omit block.
    if grep -Eq '^[[:space:]]*reverse_proxy[[:space:]]+127\.0\.0\.1:18789[[:space:]]*$' "$caddyfile" \
        && ! grep -q 'header_up -X-Forwarded' "$caddyfile"; then
        return 0
    fi

    echo "Repairing Caddy reverse_proxy for OpenClaw proxy attribution + pairing..."
    python3 - "$caddyfile" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
block = "reverse_proxy 127.0.0.1:18789"
pattern = re.compile(
    r"reverse_proxy\s+(?:localhost|127\.0\.0\.1):\d+(?:\s*\{[^}]*\})?",
    re.MULTILINE,
)
new_text, n = pattern.subn(block, text, count=1)
if n:
    path.write_text(new_text)
    print(f"Updated {path}")
else:
    print(f"No simple reverse_proxy line found in {path}; leave unchanged.", file=sys.stderr)
PY
}

repair_caddy_proxy_attribution

systemctl restart openclaw
systemctl restart caddy 2>/dev/null || true

echo ""
echo "Gateway tokens in openclaw.json:"
jq -r '.gateway.auth.token, .gateway.remote.token' /home/openclaw/.openclaw/openclaw.json
echo ""
echo "gateway.trustedProxies:"
jq -c '.gateway.trustedProxies' /home/openclaw/.openclaw/openclaw.json
echo ""
echo "Sandbox image:"
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^openclaw-sandbox:' || true
echo ""
echo "OpenClaw service:"
systemctl is-active openclaw
echo "Caddy service:"
systemctl is-active caddy 2>/dev/null || echo "inactive"
