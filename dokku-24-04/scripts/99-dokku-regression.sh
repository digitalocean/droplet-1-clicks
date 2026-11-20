#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOKKU_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

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

ALPN_LIB=$(resolve_file "/var/lib/digitalocean/nginx2root-alpn-check.sh" "${DOKKU_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh")
MITIGATE=$(resolve_file "/var/lib/digitalocean/dokku-mitigate-nginx2root.sh" "${DOKKU_DIR}/files/var/lib/digitalocean/dokku-mitigate-nginx2root.sh")
LAYOUT=$(resolve_file "/var/lib/digitalocean/nginx-org-layout.sh" "${DOKKU_DIR}/../common/files/var/lib/digitalocean/nginx-org-layout.sh")
SIGIL_FIND=$(resolve_file "/var/lib/digitalocean/dokku-find-nginx-sigil.sh" "${DOKKU_DIR}/../common/files/var/lib/digitalocean/dokku-find-nginx-sigil.sh")

bash -n "${MITIGATE}"
bash -n "${SIGIL_FIND}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"
# shellcheck source=/dev/null
source "${SIGIL_FIND}"

if ! SIGIL=$(dokku_nginx_sigil_first); then
  echo "regression: Dokku nginx sigil template missing (is dokku installed?)" >&2
  exit 1
fi

if grep 'listen' "${SIGIL}" | grep 'http2' >/dev/null; then
  echo "regression: Dokku sigil still references http2 on listen lines" >&2
  exit 1
fi

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

for f in /etc/nginx/conf.d/*.conf; do
  [ -f "${f}" ] || continue
  if nginx_site_listens_with_http2 "${f}"; then
    echo "regression: ${f} has active listen … http2" >&2
    exit 1
  fi
done

echo "dokku-24-04 regression checks ok (CVE-2026-123007 mitigation)"