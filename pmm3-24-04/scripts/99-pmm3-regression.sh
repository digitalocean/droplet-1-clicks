#!/bin/bash
# Build-time checks for PMM3 CVE-2026-123007 mitigation.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PMM_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

# Packer uploads scripts to /tmp; validate files on the guest image.
DEFAULT_MITIGATE="/var/lib/digitalocean/pmm-mitigate-nginx2root.sh"
DEFAULT_ALPN="/var/lib/digitalocean/nginx2root-alpn-check.sh"
DEFAULT_SYSTEMD="/etc/systemd/system/pmm-mitigate-nginx2root.service"
DEFAULT_ONBOOT="/var/lib/cloud/scripts/per-instance/01-setup-pmm3.sh"

resolve_file() {
  local primary=$1
  local alt=$2
  if [ -f "${primary}" ]; then
    printf '%s' "${primary}"
  elif [ -n "${alt}" ] && [ -f "${alt}" ]; then
    printf '%s' "${alt}"
  else
    echo "regression: missing file (expected ${primary} or ${alt})" >&2
    exit 1
  fi
}

DEFAULT_SYSTEMD="/etc/systemd/system/pmm-mitigate-nginx2root.service"

MITIGATE=$(resolve_file "${DEFAULT_MITIGATE}" "${PMM_DIR}/files/var/lib/digitalocean/pmm-mitigate-nginx2root.sh")
ALPN_LIB=$(resolve_file "${DEFAULT_ALPN}" "${PMM_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh")
ONBOOT=$(resolve_file "${DEFAULT_ONBOOT}" "${PMM_DIR}/files/var/lib/cloud/scripts/per-instance/01-setup-pmm3.sh")
SYSTEMD_UNIT=$(resolve_file "${DEFAULT_SYSTEMD}" "${PMM_DIR}/files/etc/systemd/system/pmm-mitigate-nginx2root.service")

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${MITIGATE}" "${ALPN_LIB}"
else
  echo "regression: skipping shellcheck (not installed)"
fi

bash -n "${ONBOOT}"
bash -n "${MITIGATE}"

# shellcheck source=/dev/null
source "${ALPN_LIB}"

grep -q 'pmm-mitigate-nginx2root.sh' "${SYSTEMD_UNIT}"

if ! docker ps --format '{{.Names}}' | grep -qx pmm-server; then
  echo "regression: pmm-server container not running during build" >&2
  exit 1
fi

# Mitigation must have waited for TLS material; cert should exist post-build.
if ! docker exec pmm-server test -f /srv/nginx/certificate.crt 2>/dev/null; then
  echo "regression: PMM certificate not present after install" >&2
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

if docker exec pmm-server sh -c 'grep -v "^#" /etc/nginx/conf.d/pmm.conf | grep -qE "^[[:space:]]*on;"'; then
  echo "regression: pmm.conf contains orphan on; directive" >&2
  exit 1
fi

if ! docker exec pmm-server nginx -t >/dev/null 2>&1; then
  echo "regression: nginx -t failed inside pmm-server" >&2
  docker exec pmm-server nginx -t || true
  exit 1
fi

assert_alpn_no_h2 "PMM Server" 127.0.0.1 443

echo "pmm3-24-04 regression checks ok (CVE-2026-123007 mitigation)"