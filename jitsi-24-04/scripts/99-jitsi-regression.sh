#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
JITSI_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
ALPN_LIB="${JITSI_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh"
SETUP="${JITSI_DIR}/files/var/complete-jitsi-setup.sh"
MITIGATE="${JITSI_DIR}/files/var/lib/digitalocean/jitsi-mitigate-nginx2root.sh"

for f in "${ALPN_LIB}" "${SETUP}" "${MITIGATE}"; do
  if [ ! -f "${f}" ]; then
    echo "regression: missing ${f}" >&2
    exit 1
  fi
done

bash -n "${SETUP}"
bash -n "${MITIGATE}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"

if grep -v '^[[:space:]]*#' "${SETUP}" | grep -q 'listen 443 ssl http2'; then
  echo "regression: complete-jitsi-setup.sh must not add listen … http2" >&2
  exit 1
fi

if ! grep -q 'listen 443 ssl;' "${SETUP}"; then
  echo "regression: complete-jitsi-setup.sh must add HTTPS without http2" >&2
  exit 1
fi

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

for f in /etc/nginx/sites-enabled/* /etc/nginx/sites-available/*; do
  [ -f "${f}" ] || continue
  if nginx_site_listens_with_http2 "${f}"; then
    echo "regression: ${f} still has active listen … http2" >&2
    exit 1
  fi
done

echo "jitsi-24-04 regression checks ok (CVE-2026-123007 mitigation)"