#!/bin/bash
# Build-time checks for Supabase after restoring HTTP/2 (Kong ≥ 3.9.5, host nginx ≥ 1.31.9).
set -euo pipefail

: "${application_version:?application_version must be set}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SUPABASE_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)

COMPOSE_DIR="/srv/supabase/supabase/docker"
ENV_FILE="${COMPOSE_DIR}/.env"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

DEFAULT_SSL_TEMPLATE="/var/supabase/supabase_ssl"
DEFAULT_ALPN="/var/lib/digitalocean/nginx2root-alpn-check.sh"
DEFAULT_ONBOOT="/var/lib/cloud/scripts/per-instance/001_onboot"
DEFAULT_NGX="/etc/nginx/sites-available/supabase"
DEFAULT_MOTD="/etc/update-motd.d/99-one-click"
DEFAULT_MITIGATE="/var/lib/digitalocean/mitigate-nginx2root.sh"

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
ALPN_LIB=$(resolve_file "${DEFAULT_ALPN}" "${SUPABASE_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh")
ONBOOT=$(resolve_file "${DEFAULT_ONBOOT}" "${SUPABASE_DIR}/files/var/lib/cloud/scripts/per-instance/001_onboot")
NGX_SITE=$(resolve_file "${DEFAULT_NGX}" "${SUPABASE_DIR}/files/etc/nginx/sites-available/supabase")
MOTD=$(resolve_file "${DEFAULT_MOTD}" "${SUPABASE_DIR}/files/etc/update-motd.d/99-one-click")

if [ -e "${DEFAULT_MITIGATE}" ] || [ -e "${SUPABASE_DIR}/files/var/lib/digitalocean/mitigate-nginx2root.sh" ]; then
  echo "regression: mitigate-nginx2root.sh must be removed (HTTP/2 re-enabled)" >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x "${ALPN_LIB}"
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

if ! grep -qE 'image:[[:space:]]*kong/kong:3\.9\.5' "${COMPOSE_FILE}"; then
  echo "regression: docker-compose.yml must pin kong/kong:3.9.5 (CVE-2026-123007 fix)" >&2
  exit 1
fi

if grep -q 'KONG_PROXY_LISTEN: ${KONG_PROXY_LISTEN}' "${COMPOSE_FILE}" || \
   grep -q 'KONG_ADMIN_LISTEN: ${KONG_ADMIN_LISTEN}' "${COMPOSE_FILE}"; then
  echo "regression: docker-compose.yml must not inject KONG_*_LISTEN overrides" >&2
  exit 1
fi

if grep -vE '^[[:space:]]*#' "${ENV_FILE}" | grep -qE '^KONG_(PROXY|ADMIN)_LISTEN='; then
  echo "regression: ${ENV_FILE} must not set KONG_*_LISTEN (use Kong defaults with http2)" >&2
  exit 1
fi

if ! nginx_site_listens_with_http2 "${SSL_TEMPLATE}"; then
  echo "regression: supabase_ssl template must use listen … http2" >&2
  exit 1
fi

# Default (pre-domain) site is HTTP-only; http2 belongs on the TLS template.
if nginx_site_listens_with_http2 "${NGX_SITE}"; then
  echo "regression: default nginx site should not use listen … http2 (no TLS yet)" >&2
  exit 1
fi

if [ -f /etc/nginx/conf.d/default.conf ]; then
  echo "regression: /etc/nginx/conf.d/default.conf must be removed (nginx.org default)" >&2
  exit 1
fi

if ! grep -q 'sites-enabled' /etc/nginx/nginx.conf; then
  echo "regression: /etc/nginx/nginx.conf must include sites-enabled" >&2
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

verify_kong_image() {
  local out
  cd "${COMPOSE_DIR}"
  echo "regression: verifying kong/kong:3.9.5 image..."
  if ! docker compose pull kong; then
    echo "regression: docker compose pull kong failed" >&2
    return 1
  fi
  out=$(docker compose run --rm --no-deps --entrypoint /bin/sh kong -c \
    'kong version 2>/dev/null || cat /usr/local/kong/.kong_version 2>/dev/null || true')
  if ! grep -qE '3\.9\.5' <<<"${out}"; then
    echo "regression: kong container is not 3.9.5 (got: ${out:-empty})" >&2
    return 1
  fi
}

verify_kong_image

echo "supabase-24-04 regression checks ok (${application_version}, Kong 3.9.5 + HTTP/2 restored; ALPN h2 left to Harbor QA)"
