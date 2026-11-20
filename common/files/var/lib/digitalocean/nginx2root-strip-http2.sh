#!/bin/bash
# Shared helpers: strip HTTP/2 from nginx configs without breaking http2 on/off directives.
set -euo pipefail

nginx_version_triplet() {
  if ! command -v nginx >/dev/null 2>&1; then
    return 1
  fi
  nginx -v 2>&1 | sed -n 's/.*nginx\/\([0-9.]*\).*/\1/p'
}

nginx_supports_http2_off_directive() {
  local ver major minor patch
  ver=$(nginx_version_triplet) || return 1
  major=$(echo "${ver}" | cut -d. -f1)
  minor=$(echo "${ver}" | cut -d. -f2)
  patch=$(echo "${ver}" | cut -d. -f3)
  if [ "${major}" -gt 1 ]; then
    return 0
  fi
  if [ "${major}" -eq 1 ] && [ "${minor}" -gt 25 ]; then
    return 0
  fi
  if [ "${major}" -eq 1 ] && [ "${minor}" -eq 25 ] && [ "${patch:-0}" -ge 1 ]; then
    return 0
  fi
  return 1
}

nginx_remove_broken_on_directive() {
  local f="${1:?file}"
  [ -f "${f}" ] || return 0
  sed -i '/^[[:space:]]*on;[[:space:]]*$/d' "${f}"
}

nginx_normalize_http2_switch_directives() {
  local f="${1:?file}"
  [ -f "${f}" ] || return 0
  if nginx_supports_http2_off_directive; then
    sed -i -E 's/^([[:space:]]*)http2[[:space:]]+on;/\1http2 off;/' "${f}"
  else
    sed -i -E '/^[[:space:]]*http2[[:space:]]+on;/d' "${f}"
  fi
}

nginx_strip_http2_from_listen_lines_file() {
  local f="${1:?file}"
  [ -f "${f}" ] || return 0
  nginx_normalize_http2_switch_directives "${f}"
  nginx_remove_broken_on_directive "${f}"
  awk '
    /^[[:space:]]*#/ { print; next }
    /^[[:space:]]*listen[[:space:]]/ {
      line = $0
      gsub(/ ssl http2/, " ssl", line)
      gsub(/ http2 ssl/, " ssl", line)
      gsub(/ http2/, "", line)
      gsub(/[[:space:]]+;/, ";", line)
      print line
      next
    }
    { print }
  ' "${f}" >"${f}.nginx2root.tmp"
  mv "${f}.nginx2root.tmp" "${f}"
}

nginx_assert_config_or_die() {
  if ! command -v nginx >/dev/null 2>&1; then
    return 0
  fi
  if [ ! -f /etc/nginx/nginx.conf ]; then
    return 0
  fi
  if ! nginx -t; then
    echo "ERROR: nginx -t failed after HTTP/2 mitigation" >&2
    exit 1
  fi
}