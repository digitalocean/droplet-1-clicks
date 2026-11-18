#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOKKU_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
ALPN_LIB="${DOKKU_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh"
SIGIL=/var/lib/dokku/core-plugins/available/nginx-vhosts/templates/nginx.conf.sigil
MITIGATE="${DOKKU_DIR}/files/var/lib/digitalocean/dokku-mitigate-nginx2root.sh"

for f in "${ALPN_LIB}" "${MITIGATE}"; do
  if [ ! -f "${f}" ]; then
    echo "regression: missing ${f}" >&2
    exit 1
  fi
done

bash -n "${MITIGATE}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"

if [ ! -f "${SIGIL}" ]; then
  echo "regression: Dokku nginx sigil template missing (is dokku installed?)" >&2
  exit 1
fi

if grep -v '^[[:space:]]*{{' "${SIGIL}" | grep -q 'http2'; then
  if grep 'listen' "${SIGIL}" | grep -q 'http2'; then
    echo "regression: Dokku sigil still references http2 on listen lines" >&2
    exit 1
  fi
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

for f in /etc/nginx/conf.d/*.conf; do
  [ -f "${f}" ] || continue
  if nginx_site_listens_with_http2 "${f}"; then
    echo "regression: ${f} has active listen … http2" >&2
    exit 1
  fi
done

echo "dokku-24-04 regression checks ok (CVE-2026-123007 mitigation)"