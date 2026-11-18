#!/bin/bash
# CVE-2026-123007: Ghost-CLI may write listen … http2 on SSL vhosts.
set -euo pipefail

MITIGATE=/var/lib/digitalocean/mitigate-host-nginx-http2.sh
if [ ! -x "${MITIGATE}" ]; then
  echo "ERROR: missing ${MITIGATE}" >&2
  exit 1
fi

"${MITIGATE}" --restart

# shellcheck source=/dev/null
source /var/lib/digitalocean/nginx2root-strip-http2.sh
nginx_assert_config_or_die
systemctl restart nginx
echo "ghost-mitigate-nginx2root: HTTP/2 disabled on host nginx"