#!/bin/bash
# CVE-2026-123007: remove HTTP/2 from host nginx configs and disable it globally where supported.
set -euo pipefail

SNIPPET=/etc/nginx/conf.d/digitalocean-http2-off.conf
RESTART="${1:-}"

strip_http2_from_file() {
  local f="${1:?file}"
  [ -f "${f}" ] || return 0
  sed -i \
    -e 's/\blisten\([^;]*\) ssl http2;/listen\1 ssl;/g' \
    -e 's/\blisten\([^;]*\) http2 ssl;/listen\1 ssl;/g' \
    -e 's/\blisten\([^;]*\) http2;/listen\1;/g' \
    -e 's/ ssl http2\b/ ssl/g' \
    -e 's/ http2 ssl\b/ ssl/g' \
    -e 's/ http2\b//g' \
    "${f}"
}

ensure_global_http2_off() {
  install -d -m 0755 /etc/nginx/conf.d
  if ! [ -f "${SNIPPET}" ]; then
    cat >"${SNIPPET}" <<'EOF'
# DigitalOcean 1-Click: CVE-2026-123007 — force HTTP/1.1 over TLS (nginx >= 1.25.1).
http2 off;
EOF
    chmod 0644 "${SNIPPET}"
  fi
}

patch_tree() {
  local root="${1:-/etc/nginx}"
  [ -d "${root}" ] || return 0
  find "${root}" -type f -name '*.conf' 2>/dev/null | while read -r f; do
    strip_http2_from_file "${f}"
  done
}

main() {
  ensure_global_http2_off
  patch_tree /etc/nginx

  if [ -d /home/dokku ]; then
    find /home/dokku -maxdepth 2 -name 'nginx.conf' -type f 2>/dev/null | while read -r f; do
      strip_http2_from_file "${f}"
    done
  fi

  if ! nginx -t 2>/dev/null; then
    echo "WARN: nginx -t failed after http2 mitigation; leaving configs patched" >&2
    return 0
  fi

  if [ "${RESTART}" = "--restart" ] && systemctl is-active nginx >/dev/null 2>&1; then
    systemctl restart nginx
  fi
}

main "$@"