#!/bin/bash
# Build-time checks for PMM3 CVE-2026-123007 mitigation.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PMM_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

MITIGATE="${PMM_DIR}/files/var/lib/digitalocean/pmm-mitigate-nginx2root.sh"
ALPN_LIB="${PMM_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh"
SYSTEMD_UNIT="${PMM_DIR}/files/etc/systemd/system/pmm-mitigate-nginx2root.service"

for f in "${MITIGATE}" "${ALPN_LIB}" "${SYSTEMD_UNIT}"; do
  if [ ! -f "${f}" ]; then
    echo "regression: missing ${f}" >&2
    exit 1
  fi
done

shellcheck -x "${MITIGATE}" "${ALPN_LIB}"

# shellcheck source=/dev/null
source "${ALPN_LIB}"

if ! docker ps --format '{{.Names}}' | grep -qx pmm-server; then
  echo "regression: pmm-server container not running during build" >&2
  exit 1
fi

if docker exec pmm-server sh -c 'grep -v "^#" /etc/nginx/conf.d/pmm.conf | grep -q "listen.*http2"'; then
  echo "regression: pmm.conf still has active listen … http2" >&2
  exit 1
fi

if docker exec pmm-server sh -c 'grep -v "^#" /etc/nginx/conf.d/pmm.conf | grep -qE "^[[:space:]]*http2[[:space:]]+on"'; then
  echo "regression: pmm.conf still has http2 on" >&2
  exit 1
fi

# Public PMM HTTPS is published as host :443
assert_alpn_no_h2 "PMM Server" 127.0.0.1 443

echo "pmm3-24-04 regression checks ok (CVE-2026-123007 mitigation)"