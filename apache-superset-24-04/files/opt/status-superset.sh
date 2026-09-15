#!/bin/bash
echo "=== Apache Superset Status ==="
systemctl status superset --no-pager || true

echo ""
echo "=== Caddy Status ==="
systemctl is-active caddy >/dev/null 2>&1 && echo "caddy: active" || echo "caddy: inactive"

echo ""
echo "=== Version ==="
if [ -f /var/lib/digitalocean/application.info ]; then
  grep -E '^application_(name|version)=' /var/lib/digitalocean/application.info || true
fi

echo ""
echo "=== Access ==="
pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
priv=$(hostname -I | awk '{print $1}')
host="${pub:-$priv}"
echo "  https://${host}/"
echo "  Passwords: /root/.digitalocean_passwords"
