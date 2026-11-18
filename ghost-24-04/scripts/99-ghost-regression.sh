#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GHOST_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

resolve_file() {
  local primary=$1
  local alt=$2
  if [ -f "$primary" ]; then
    printf '%s' "$primary"
  elif [ -n "$alt" ] && [ -f "$alt" ]; then
    printf '%s' "$alt"
  else
    echo "regression: missing file (expected $primary or $alt)" >&2
    exit 1
  fi
}

ALPN_LIB=$(resolve_file "/var/lib/digitalocean/nginx2root-alpn-check.sh" "${GHOST_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh")
BOOT=$(resolve_file "/opt/ghost-setup/boot_strap.sh" "${GHOST_DIR}/files/opt/ghost-setup/boot_strap.sh")
MITIGATE=$(resolve_file "/var/lib/digitalocean/ghost-mitigate-nginx2root.sh" "${GHOST_DIR}/files/var/lib/digitalocean/ghost-mitigate-nginx2root.sh")
LAYOUT=$(resolve_file "/var/lib/digitalocean/nginx-org-layout.sh" "${GHOST_DIR}/../common/files/var/lib/digitalocean/nginx-org-layout.sh")
HTTP2_SNIPPET="/etc/nginx/conf.d/digitalocean-http2-off.conf"

bash -n "${BOOT}"
bash -n "${MITIGATE}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"

if command -v nginx >/dev/null 2>&1 && [ -f /etc/nginx/nginx.conf ]; then
  ver=$(nginx -v 2>&1 | sed -n 's/.*nginx\/\([0-9.]*\).*/\1/p')
  major=$(echo "${ver}" | cut -d. -f1)
  minor=$(echo "${ver}" | cut -d. -f2)
  patch=$(echo "${ver}" | cut -d. -f3)
  if [ "${major}" -lt 1 ] || { [ "${major}" -eq 1 ] && [ "${minor}" -lt 31 ]; } || \
     { [ "${major}" -eq 1 ] && [ "${minor}" -eq 31 ] && [ "${patch}" -lt 9 ]; }; then
    echo "regression: host nginx ${ver} is below 1.31.9" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "${LAYOUT}"
  nginx_org_install_regression_checks
fi

for f in /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* /etc/nginx/conf.d/*; do
  [ -f "${f}" ] || continue
  if nginx_site_listens_with_http2 "${f}"; then
    echo "regression: ${f} still has active listen … http2" >&2
    exit 1
  fi
done

if [ -f "${HTTP2_SNIPPET}" ]; then
  grep -q 'http2 off' "${HTTP2_SNIPPET}" || {
    echo "regression: digitalocean-http2-off.conf must set http2 off when present" >&2
    exit 1
  }
fi

echo "ghost-24-04 regression checks ok (CVE-2026-123007 mitigation)"