#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
JITSI_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

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

ALPN_LIB=$(resolve_file "/var/lib/digitalocean/nginx2root-alpn-check.sh" "${JITSI_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh")
SETUP=$(resolve_file "/var/complete-jitsi-setup.sh" "${JITSI_DIR}/files/var/complete-jitsi-setup.sh")
MITIGATE=$(resolve_file "/var/lib/digitalocean/jitsi-mitigate-nginx2root.sh" "${JITSI_DIR}/files/var/lib/digitalocean/jitsi-mitigate-nginx2root.sh")
STRIP_LIB=$(resolve_file "/var/lib/digitalocean/nginx2root-strip-http2.sh" "${JITSI_DIR}/../common/files/var/lib/digitalocean/nginx2root-strip-http2.sh")
LAYOUT=$(resolve_file "/var/lib/digitalocean/nginx-org-layout.sh" "${JITSI_DIR}/../common/files/var/lib/digitalocean/nginx-org-layout.sh")

bash -n "${SETUP}"
bash -n "${MITIGATE}"
bash -n "${STRIP_LIB}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"

if grep -v '^[[:space:]]*#' "${SETUP}" | grep 'listen 443 ssl http2' >/dev/null; then
  echo "regression: complete-jitsi-setup.sh must not add listen … http2" >&2
  exit 1
fi

if ! grep -q 'listen 443 ssl;' "${SETUP}"; then
  echo "regression: complete-jitsi-setup.sh must add HTTPS without http2" >&2
  exit 1
fi

if ! grep -q 'register_prosody_focus_and_jvb' "${SETUP}"; then
  echo "regression: complete-jitsi-setup.sh must register focus and jvb on auth.\${domain}" >&2
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

for f in /etc/nginx/sites-enabled/* /etc/nginx/sites-available/*; do
  [ -f "${f}" ] || continue
  if nginx_site_listens_with_http2 "${f}"; then
    echo "regression: ${f} still has active listen … http2" >&2
    exit 1
  fi
done

echo "jitsi-24-04 regression checks ok (CVE-2026-123007 mitigation)"