#!/bin/bash
# CVE-2026-123007: Ghost-CLI may write listen … http2 on SSL vhosts.
set -euo pipefail

MITIGATE=/var/lib/digitalocean/mitigate-host-nginx-http2.sh
if [ ! -x "${MITIGATE}" ]; then
  echo "ERROR: missing ${MITIGATE}" >&2
  exit 1
fi

"${MITIGATE}" --restart
nginx -t
systemctl restart nginx
echo "ghost-mitigate-nginx2root: HTTP/2 disabled on host nginx"