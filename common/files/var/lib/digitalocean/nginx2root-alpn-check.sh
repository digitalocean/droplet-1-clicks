#!/bin/bash
# CVE-2026-123007 (nginx2root): detect HTTP/2 (ALPN h2) on a TLS listener.
# Sourced by build-time regression and first-boot checks.
set -euo pipefail

# Return 0 if the server negotiates ALPN h2 when the client offers h2,http/1.1.
alpn_advertises_h2() {
  local host="${1:?host}"
  local port="${2:?port}"
  local servername="${3:-localhost}"
  local out

  if ! command -v openssl >/dev/null 2>&1; then
    echo "alpn check: openssl not found" >&2
    return 2
  fi

  out=$(
    echo |
      timeout 15 openssl s_client \
        -connect "${host}:${port}" \
        -servername "${servername}" \
        -alpn h2,http/1.1 2>/dev/null || true
  )
  grep -q 'ALPN protocol: h2' <<<"${out}"
}

assert_alpn_no_h2() {
  local label="${1:?label}"
  local host="${2:?host}"
  local port="${3:?port}"
  local servername="${4:-localhost}"

  if alpn_advertises_h2 "${host}" "${port}" "${servername}"; then
    echo "regression: ${label} (${host}:${port}) negotiates ALPN h2 (CVE-2026-123007)" >&2
    return 1
  fi
  return 0
}

assert_alpn_h2() {
  local label="${1:?label}"
  local host="${2:?host}"
  local port="${3:?port}"
  local servername="${4:-localhost}"

  if ! alpn_advertises_h2 "${host}" "${port}" "${servername}"; then
    echo "regression: ${label} (${host}:${port}) did not negotiate ALPN h2" >&2
    return 1
  fi
  return 0
}

# Active listen lines only (ignore comments and pseudo-directives in other contexts).
nginx_site_listens_with_http2() {
  local f="${1:?config}"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*listen[[:space:]]/ && /http2/ { found=1; exit }
    END { exit !found }
  ' "${f}"
}

kong_env_has_http2_listen() {
  local env_file="${1:?env}"
  awk '
    /^[[:space:]]*#/ { next }
    /^KONG_(PROXY|ADMIN)_LISTEN=/ && /http2/ { found=1; exit }
    END { exit !found }
  ' "${env_file}"
}

# Active http2 on; or listen … http2 (ignore comments).
nginx_config_enables_http2() {
  local f="${1:?config}"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*http2[[:space:]]+on;/ { found=1; exit }
    /^[[:space:]]*listen[[:space:]]/ && /http2/ { found=1; exit }
    END { exit !found }
  ' "${f}"
}

# Any non-comment line with an active listen directive advertising http2.
nginx_configs_have_listen_http2() {
  local path="${1:?path}"
  if [ -d "${path}" ]; then
    find "${path}" -type f -name '*.conf' 2>/dev/null | while read -r f; do
      nginx_site_listens_with_http2 "${f}" && exit 0
    done
    return 1
  fi
  nginx_site_listens_with_http2 "${path}"
}
