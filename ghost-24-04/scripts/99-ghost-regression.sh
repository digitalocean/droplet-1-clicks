#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GHOST_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
ALPN_LIB="${GHOST_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh"
BOOT="${GHOST_DIR}/files/opt/ghost-setup/boot_strap.sh"
MITIGATE="${GHOST_DIR}/files/var/lib/digitalocean/ghost-mitigate-nginx2root.sh"

for f in "${ALPN_LIB}" "${BOOT}" "${MITIGATE}"; do
  if [ ! -f "${f}" ]; then
    echo "regression: missing ${f}" >&2
    exit 1
  fi
done

bash -n "${BOOT}"
bash -n "${MITIGATE}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"

if command -v nginx >/dev/null 2>&1; then
  ver=$(nginx -v 2>&1 | sed -n 's/.*nginx\/\([0-9.]*\).*/\1/p')
  major=$(echo "${ver}" | cut -d. -f1)
  minor=$(echo "${ver}" | cut -d. -f2)
  patch=$(echo "${ver}" | cut -d. -f3)
  if [ "${major}" -lt 1 ] || { [ "${major}" -eq 1 ] && [ "${minor}" -lt 31 ]; } || \
     { [ "${major}" -eq 1 ] && [ "${minor}" -eq 31 ] && [ "${patch}" -lt 9 ]; }; then
    echo "regression: host nginx ${ver} is below 1.31.9" >&2
    exit 1
  fi
  nginx -t
fi

for f in /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* /etc/nginx/conf.d/*; do
  [ -f "${f}" ] || continue
  if nginx_site_listens_with_http2 "${f}"; then
    echo "regression: ${f} still has active listen … http2" >&2
    exit 1
  fi
done

if [ ! -f /etc/nginx/conf.d/digitalocean-http2-off.conf ]; then
  echo "regression: missing global http2 off snippet" >&2
  exit 1
fi

grep -q 'http2 off' /etc/nginx/conf.d/digitalocean-http2-off.conf || {
  echo "regression: digitalocean-http2-off.conf must set http2 off" >&2
  exit 1
}

echo "ghost-24-04 regression checks ok (CVE-2026-123007 mitigation)"