#!/bin/bash
# CVE-2026-123007 mitigation for Jitsi host nginx.
set -euo pipefail

MITIGATE=/var/lib/digitalocean/mitigate-host-nginx-http2.sh

if [ -x "${MITIGATE}" ]; then
  "${MITIGATE}" --restart
else
  echo "ERROR: missing ${MITIGATE}" >&2
  exit 1
fi

# Jitsi packages may rewrite nginx vhosts on upgrade; strip http2 again.
for f in /etc/nginx/sites-enabled/* /etc/nginx/sites-available/*; do
  [ -f "${f}" ] || continue
  sed -i \
    -e 's/\blisten\([^;]*\) ssl http2;/listen\1 ssl;/g' \
    -e 's/ ssl http2\b/ ssl/g' \
  "${f}"
done

nginx -t
systemctl restart nginx
echo "jitsi-mitigate-nginx2root: HTTP/2 disabled on host nginx"