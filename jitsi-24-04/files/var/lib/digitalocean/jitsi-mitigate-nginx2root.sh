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

# shellcheck source=/dev/null
source /var/lib/digitalocean/nginx2root-strip-http2.sh

for f in /etc/nginx/sites-enabled/* /etc/nginx/sites-available/*; do
  [ -f "${f}" ] || continue
  nginx_strip_http2_from_listen_lines_file "${f}"
done

nginx_assert_config_or_die
systemctl restart nginx
echo "jitsi-mitigate-nginx2root: HTTP/2 disabled on host nginx"