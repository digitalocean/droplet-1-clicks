#!/bin/bash
set -euo pipefail

if [ -x /var/lib/digitalocean/jitsi-mitigate-nginx2root.sh ]; then
  /var/lib/digitalocean/jitsi-mitigate-nginx2root.sh
fi

if [ -f /var/lib/digitalocean/nginx2root-alpn-check.sh ]; then
  # shellcheck source=/dev/null
  source /var/lib/digitalocean/nginx2root-alpn-check.sh
  if systemctl is-active nginx >/dev/null 2>&1 && ss -tln 2>/dev/null | grep ':443 ' >/dev/null; then
    servername=localhost
    for f in /etc/nginx/sites-enabled/*.conf; do
      [ -f "${f}" ] || continue
      servername=$(basename "${f}" .conf)
      break
    done
    assert_alpn_no_h2 "Jitsi nginx (first boot)" 127.0.0.1 443 "${servername}" || true
  fi
fi