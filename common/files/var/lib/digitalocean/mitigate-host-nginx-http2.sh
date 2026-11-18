#!/bin/bash
# CVE-2026-123007: remove HTTP/2 from host nginx configs and disable it globally where supported.
set -euo pipefail

SNIPPET=/etc/nginx/conf.d/digitalocean-http2-off.conf
RESTART="${1:-}"

# shellcheck source=/dev/null
source /var/lib/digitalocean/nginx2root-strip-http2.sh

ensure_global_http2_off() {
  install -d -m 0755 /etc/nginx/conf.d
  if ! nginx_supports_http2_off_directive; then
    rm -f "${SNIPPET}"
    return 0
  fi
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
    nginx_strip_http2_from_listen_lines_file "${f}"
  done
}

main() {
  ensure_global_http2_off
  patch_tree /etc/nginx

  if [ -d /home/dokku ]; then
    find /home/dokku -maxdepth 2 -name 'nginx.conf' -type f 2>/dev/null | while read -r f; do
      nginx_strip_http2_from_listen_lines_file "${f}"
    done
  fi

  nginx_assert_config_or_die

  if [ "${RESTART}" = "--restart" ] && systemctl is-active nginx >/dev/null 2>&1; then
    systemctl restart nginx
  fi
}

main "$@"