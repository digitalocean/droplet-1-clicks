#!/bin/bash
# Build-time checks for Supabase CVE-2026-123007 mitigation.
set -euo pipefail

: "${application_version:?application_version must be set}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SUPABASE_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

ENV_FILE="/srv/supabase/supabase/docker/.env"

# Packer guest paths; fall back to repo layout for local runs.
DEFAULT_SSL_TEMPLATE="/var/supabase/supabase_ssl"
DEFAULT_MITIGATE="/var/lib/digitalocean/mitigate-nginx2root.sh"
DEFAULT_ALPN="/var/lib/digitalocean/nginx2root-alpn-check.sh"
DEFAULT_ONBOOT="/var/lib/cloud/scripts/per-instance/001_onboot"
DEFAULT_NGX="/etc/nginx/sites-available/supabase"
DEFAULT_MOTD="/etc/update-motd.d/99-one-click"

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

SSL_TEMPLATE=$(resolve_file "${DEFAULT_SSL_TEMPLATE}" "${SUPABASE_DIR}/files/var/supabase/supabase_ssl")
MITIGATE=$(resolve_file "${DEFAULT_MITIGATE}" "${SUPABASE_DIR}/files/var/lib/digitalocean/mitigate-nginx2root.sh")
ALPN_LIB=$(resolve_file "${DEFAULT_ALPN}" "${SUPABASE_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh")
ONBOOT=$(resolve_file "${DEFAULT_ONBOOT}" "${SUPABASE_DIR}/files/var/lib/cloud/scripts/per-instance/001_onboot")
NGX_SITE=$(resolve_file "${DEFAULT_NGX}" "${SUPABASE_DIR}/files/etc/nginx/sites-available/supabase")
MOTD=$(resolve_file "${DEFAULT_MOTD}" "${SUPABASE_DIR}/files/etc/update-motd.d/99-one-click")

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${MITIGATE}" "${ALPN_LIB}"
else
  echo "regression: skipping shellcheck (not installed)"
fi

bash -n "${ONBOOT}"
sh -n "${MOTD}"

# shellcheck source=/dev/null
source "${ALPN_LIB}"

if [ ! -f "${ENV_FILE}" ]; then
  echo "regression: missing ${ENV_FILE} (Supabase clone step should create it)" >&2
  exit 1
fi

if [ ! -d /srv/supabase/supabase/.git ]; then
  echo "regression: missing /srv/supabase/supabase clone" >&2
  exit 1
fi

checked_out=$(git -C /srv/supabase/supabase describe --tags --exact-match 2>/dev/null || true)
if [ "${checked_out}" != "${application_version}" ]; then
  echo "regression: checked out ${checked_out:-unknown} != application_version ${application_version}" >&2
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
  if ! nginx -t >/dev/null 2>&1; then
    echo "regression: nginx -t failed on build host" >&2
    nginx -t || true
    exit 1
  fi
else
  echo "regression: nginx binary missing on build host" >&2
  exit 1
fi

if docker ps --format '{{.Names}}' | grep -qx supabase-kong; then
  https_port=$(sed -n 's/^KONG_HTTPS_PORT=//p' "${ENV_FILE}" | tail -n1)
  https_port="${https_port:-8443}"
  assert_alpn_no_h2 "Kong HTTPS" 127.0.0.1 "${https_port}"
fi

echo "supabase-24-04 regression checks ok (${application_version}, CVE-2026-123007 mitigation)"