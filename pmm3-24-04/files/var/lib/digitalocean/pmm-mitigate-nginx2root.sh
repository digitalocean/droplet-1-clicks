#!/bin/bash
# CVE-2026-123007: PMM ships nginx inside pmm-server without a distro fix yet —
# disable HTTP/2 in the container and restart nginx (reload alone is insufficient).
set -euo pipefail

CONTAINER_NAME="${PMM_CONTAINER_NAME:-pmm-server}"
PMM_CONF="/etc/nginx/conf.d/pmm.conf"
PMM_CERT="/srv/nginx/certificate.crt"
PMM_READY_TIMEOUT="${PMM_READY_TIMEOUT:-600}"

container_running() {
  docker ps --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"
}

pmm_tls_ready() {
  if docker exec "${CONTAINER_NAME}" test -f "${PMM_CERT}" 2>/dev/null; then
    return 0
  fi
  local code
  code=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 15 \
    "https://127.0.0.1:443/v1/readyz" 2>/dev/null || echo "000")
  [ "${code}" = "200" ]
}

wait_for_pmm_ready() {
  local start now elapsed
  start=$(date +%s)

  echo "pmm-mitigate-nginx2root: waiting for PMM TLS readiness (timeout ${PMM_READY_TIMEOUT}s)..."
  while true; do
    if ! container_running; then
      echo "ERROR: ${CONTAINER_NAME} is not running" >&2
      return 1
    fi
    if pmm_tls_ready; then
      echo "pmm-mitigate-nginx2root: PMM TLS is ready"
      return 0
    fi
    now=$(date +%s)
    elapsed=$((now - start))
    if [ "${elapsed}" -ge "${PMM_READY_TIMEOUT}" ]; then
      echo "ERROR: timed out waiting for ${PMM_CERT} or /v1/readyz=200" >&2
      return 1
    fi
    sleep 5
  done
}

patch_pmm_nginx_conf() {
  local f="$1"
  if [ ! -f "${f}" ]; then
    echo "ERROR: missing ${f} in ${CONTAINER_NAME}" >&2
    return 1
  fi

  sed -i \
    -e '/^[[:space:]]*http2[[:space:]]*on;/d' \
    -e 's/^[[:space:]]*http2[[:space:]]*off;/http2 off;/' \
    "${f}"

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
  docker exec "${CONTAINER_NAME}" bash -c 'if pidof nginx >/dev/null; then kill "$(pidof nginx)"; fi'
  sleep 1
  docker exec "${CONTAINER_NAME}" nginx
}

main() {
  if ! container_running; then
    echo "pmm-mitigate-nginx2root: ${CONTAINER_NAME} not running (skipped)" >&2
    return 0
  fi

  wait_for_pmm_ready

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