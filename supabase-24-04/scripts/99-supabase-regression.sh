#!/bin/bash
# Build-time checks for Supabase CVE-2026-123007 mitigation.
set -euo pipefail

: "${application_version:?application_version must be set}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SUPABASE_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

ENV_FILE="/srv/supabase/supabase/docker/.env"
SSL_TEMPLATE="${SUPABASE_DIR}/files/var/supabase/supabase_ssl"
MITIGATE="${SUPABASE_DIR}/files/var/lib/digitalocean/mitigate-nginx2root.sh"
ALPN_LIB="${SUPABASE_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh"
ONBOOT="${SUPABASE_DIR}/files/var/lib/cloud/scripts/per-instance/001_onboot"
NGX_SITE="${SUPABASE_DIR}/files/etc/nginx/sites-available/supabase"

for f in "${SSL_TEMPLATE}" "${MITIGATE}" "${ALPN_LIB}" "${ONBOOT}" "${NGX_SITE}"; do
  if [ ! -f "${f}" ]; then
    echo "regression: missing ${f}" >&2
    exit 1
  fi
done

shellcheck -x "${MITIGATE}" "${ALPN_LIB}"
bash -n "${ONBOOT}"
sh -n "${SUPABASE_DIR}/files/etc/update-motd.d/99-one-click"

# shellcheck source=/dev/null
source "${ALPN_LIB}"

if [ ! -f "${ENV_FILE}" ]; then
  echo "regression: missing ${ENV_FILE} (Supabase clone step should create it)" >&2
  exit 1
fi

if kong_env_has_http2_listen "${ENV_FILE}"; then
  echo "regression: ${ENV_FILE} must not set KONG_*_LISTEN with http2" >&2
  exit 1
fi

if ! grep -q '^KONG_PROXY_LISTEN=0\.0\.0\.0:8000' "${ENV_FILE}"; then
  echo "regression: KONG_PROXY_LISTEN must be set without http2" >&2
  exit 1
fi

if nginx_site_listens_with_http2 "${SSL_TEMPLATE}"; then
  echo "regression: supabase_ssl template must not use listen … http2" >&2
  exit 1
fi

if nginx_site_listens_with_http2 "${NGX_SITE}"; then
  echo "regression: default nginx site must not use listen … http2 (pre-domain)" >&2
  exit 1
fi

if command -v nginx >/dev/null 2>&1; then
  ver=$(nginx -v 2>&1 | sed -n 's/.*nginx\/\([0-9.]*\).*/\1/p')
  major=$(echo "${ver}" | cut -d. -f1)
  minor=$(echo "${ver}" | cut -d. -f2)
  patch=$(echo "${ver}" | cut -d. -f3)
  if [ "${major}" -lt 1 ] || { [ "${major}" -eq 1 ] && [ "${minor}" -lt 31 ]; } || \
     { [ "${major}" -eq 1 ] && [ "${minor}" -eq 31 ] && [ "${patch}" -lt 9 ]; }; then
    echo "regression: host nginx ${ver} is below 1.31.9 (CVE-2026-123007)" >&2
    exit 1
  fi
  nginx -t
else
  echo "regression: nginx binary missing on build host" >&2
  exit 1
fi

# Kong may not be running during image build; skip live ALPN unless the container exists.
if docker ps --format '{{.Names}}' | grep -qx supabase-kong; then
  https_port=$(sed -n 's/^KONG_HTTPS_PORT=//p' "${ENV_FILE}" | tail -n1)
  https_port="${https_port:-8443}"
  assert_alpn_no_h2 "Kong HTTPS" 127.0.0.1 "${https_port}"
fi

echo "supabase-24-04 regression checks ok (${application_version}, CVE-2026-123007 mitigation)"