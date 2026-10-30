#!/bin/bash
set -euo pipefail

meta() { curl -fsS --retry 3 --retry-connrefused --max-time 2 "$1" 2>/dev/null || true; }
DROPLET_PUBLIC_IP="$(meta http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)"
DROPLET_IP="${DROPLET_PUBLIC_IP:-$(hostname -I | awk '{print $1}')}"

echo "=== Paperclip service ==="
systemctl --no-pager --full status paperclip || true
echo
echo "=== PostgreSQL service ==="
systemctl --no-pager --full status postgresql || true
echo
echo "=== Caddy service ==="
systemctl --no-pager --full status caddy || true
echo
echo "=== Version ==="
if [ -x /home/paperclip/.local/bin/paperclipai ]; then
  su - paperclip -c "paperclipai --version" 2>/dev/null || true
fi
grep -E '^PAPERCLIP_VERSION=' /opt/paperclip.env 2>/dev/null || true
echo
echo "=== Database ==="
if [ -f /home/paperclip/.paperclip/instances/default/config.json ]; then
  python3 - <<'PY' 2>/dev/null || echo "config: unreadable"
import json
cfg = json.load(open("/home/paperclip/.paperclip/instances/default/config.json", encoding="utf-8"))
db = cfg.get("database") or {}
print(f"mode: {db.get('mode', 'unknown')}")
print(f"connectionString: {'set' if db.get('connectionString') else 'missing'}")
PY
fi
if grep -qE '^DATABASE_URL=postgres(ql)?://' /opt/paperclip.env 2>/dev/null; then
  echo "DATABASE_URL: set in /opt/paperclip.env"
else
  echo "DATABASE_URL: missing or invalid in /opt/paperclip.env"
fi
if command -v pg_isready >/dev/null 2>&1; then
  sudo -u postgres pg_isready 2>/dev/null || pg_isready -h 127.0.0.1 -p 5432 || true
fi
echo
echo "=== Health ==="
if curl -fsS --max-time 5 "http://127.0.0.1:3100/api/health" >/dev/null 2>&1; then
  echo "Loopback health: OK (http://127.0.0.1:3100/api/health)"
else
  echo "Loopback health: unavailable"
fi
echo "Dashboard: https://${DROPLET_IP}"
if [ -f /opt/paperclip.env ]; then
  echo "Email:     $(grep -E '^ADMIN_EMAIL=' /opt/paperclip.env | cut -d= -f2-)"
  echo "Password:  $(grep -E '^INITIAL_PASSWORD=' /opt/paperclip.env | cut -d= -f2-)"
fi
echo
echo "=== Serverless Inference ==="
if [ -f /opt/paperclip/.provider-configured ]; then
  echo "DigitalOcean key: staged in /opt/paperclip.env (connect providers in UI)"
  grep -E '^(INFERENCE_MODEL|DO_INFERENCE_ROUTER|OPENAI_BASE_URL)=' /opt/paperclip.env 2>/dev/null || true
  if grep -qE '^MODEL_ACCESS_KEY=.' /opt/paperclip.env 2>/dev/null; then
    echo "MODEL_ACCESS_KEY: set"
  else
    echo "MODEL_ACCESS_KEY: missing"
  fi
else
  echo "DigitalOcean key: not staged (optional — run /etc/setup_wizard.sh)"
fi
if [ -f /root/paperclip_firstboot_failed ]; then
  echo
  echo "=== First-boot failure ==="
  cat /root/paperclip_firstboot_failed
fi
if [ -f /root/paperclip_bootstrap_invite.txt ]; then
  echo
  echo "=== Bootstrap invite ==="
  cat /root/paperclip_bootstrap_invite.txt
fi
