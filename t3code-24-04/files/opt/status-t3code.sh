#!/bin/bash
echo "=== T3 Code Service Status ==="
systemctl status t3code --no-pager || true

echo ""
echo "=== Caddy Status ==="
systemctl is-active caddy >/dev/null 2>&1 && echo "caddy: active" || echo "caddy: inactive"

echo ""
echo "=== Web UI ==="
pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
priv=$(hostname -I | awk '{print $1}')
host="${pub:-$priv}"
echo "  https://${host}/   (Caddy -> T3 Code on 127.0.0.1:3773)"

echo ""
echo "=== Pairing ==="
if [ -f /root/.t3code-pairing.txt ]; then
  echo "  Pairing link: /root/.t3code-pairing.txt"
else
  echo "  No pairing link yet. Create one with: /opt/create-t3code-pairing.sh"
fi

echo ""
echo "=== Provider binaries ==="
for cmd in t3 claude codex cursor-agent grok opencode pi muse fx; do
  if [ -x "/usr/local/bin/${cmd}" ]; then
    echo "  ${cmd}: $(/usr/local/bin/${cmd} --version 2>/dev/null | head -n 1 || echo present)"
  else
    echo "  ${cmd}: missing"
  fi
done
if [ -x /opt/antigravity-acp/current/agy_acp_server.par ]; then
  echo "  antigravity: /opt/antigravity-acp/current/agy_acp_server.par"
fi

echo ""
echo "=== Inference ==="
if [ -f /home/t3/.t3/inference-configured ]; then
  echo "  DigitalOcean Serverless Inference is configured."
  if [ -f /opt/t3code-inference.env ]; then
    grep -E '^(INFERENCE_MODEL|DO_INFERENCE_ROUTER)=' /opt/t3code-inference.env || true
  fi
else
  echo "  Not configured. Run: /etc/setup_wizard.sh"
fi
