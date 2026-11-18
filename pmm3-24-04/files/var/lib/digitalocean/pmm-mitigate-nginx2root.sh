#!/bin/bash
# CVE-2026-123007: PMM ships nginx inside pmm-server without a distro fix yet —
# disable HTTP/2 in the container and restart nginx (reload alone is insufficient).
set -euo pipefail

CONTAINER_NAME="${PMM_CONTAINER_NAME:-pmm-server}"
PMM_CONF="/etc/nginx/conf.d/pmm.conf"

container_running() {
  docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"
}

patch_pmm_nginx_conf() {
  local f="$1"
  if [ ! -f "${f}" ]; then
    echo "ERROR: missing ${f} in ${CONTAINER_NAME}" >&2
    return 1
  fi

  # Standalone http2 directive first (nginx 1.25+). Do this before any global " http2 " substitution
  # that would corrupt "http2 on;" into "on;".
  sed -i \
    -e '/^[[:space:]]*http2[[:space:]]*on;/d' \
    -e 's/^[[:space:]]*http2[[:space:]]*off;/http2 off;/' \
    "${f}"

  # Remove http2 only from listen lines (legacy "listen … ssl http2;").
  sed -i -E '/^[[:space:]]*listen[[:space:]]/{
    s/[[:space:]]+http2([[:space:]]*;)/\1/
    s/[[:space:]]+http2([[:space:]]+)/ /
  }' "${f}"

  if grep -vE '^[[:space:]]*#' "${f}" | grep -qE 'listen[[:space:]].*http2'; then
    echo "ERROR: ${f} still contains listen … http2 after patch" >&2
    return 1
  fi
  if grep -vE '^[[:space:]]*#' "${f}" | grep -qE '^[[:space:]]*http2[[:space:]]+on'; then
    echo "ERROR: ${f} still enables http2 via directive" >&2
    return 1
  fi
  if grep -vE '^[[:space:]]*#' "${f}" | grep -qE '^[[:space:]]*on;'; then
    echo "ERROR: ${f} contains orphan \"on;\" directive (bad http2 patch)" >&2
    return 1
  fi
  return 0
}

restart_pmm_nginx() {
  if docker exec "${CONTAINER_NAME}" supervisorctl status nginx >/dev/null 2>&1; then
    docker exec "${CONTAINER_NAME}" supervisorctl restart nginx
    return 0
  fi
  # Fallback: signal master (full restart, not reload)
  docker exec "${CONTAINER_NAME}" bash -c 'if pidof nginx >/dev/null; then kill "$(pidof nginx)"; fi'
  sleep 1
  docker exec "${CONTAINER_NAME}" nginx
}

main() {
  if ! container_running; then
    echo "pmm-mitigate-nginx2root: ${CONTAINER_NAME} not running (skipped)" >&2
    return 0
  fi

  tmp=$(mktemp)
  docker cp "${CONTAINER_NAME}:${PMM_CONF}" "${tmp}"
  patch_pmm_nginx_conf "${tmp}"
  docker cp "${tmp}" "${CONTAINER_NAME}:${PMM_CONF}"
  rm -f "${tmp}"

  if ! docker exec "${CONTAINER_NAME}" nginx -t; then
    echo "ERROR: nginx -t failed in ${CONTAINER_NAME} after HTTP/2 mitigation" >&2
    exit 1
  fi
  restart_pmm_nginx
  echo "pmm-mitigate-nginx2root: HTTP/2 disabled in ${CONTAINER_NAME} nginx"
}

main "$@"