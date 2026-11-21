#!/bin/bash
set -euo pipefail

meta() { curl -fsS --retry 3 --retry-connrefused --max-time 2 "$1"; }
DROPLET_PUBLIC_IP="$(meta http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
DROPLET_PRIVATE_IP="$(hostname -I | awk '{print $1}')"
DROPLET_IP="${DROPLET_PUBLIC_IP:-$DROPLET_PRIVATE_IP}"

echo "Prometheus: $(systemctl is-active prometheus 2>/dev/null || echo unknown)"
echo "Caddy:      $(systemctl is-active caddy 2>/dev/null || echo unknown)"
echo "UI:         https://${DROPLET_IP}/"
echo
systemctl --no-pager --full status prometheus caddy || true
