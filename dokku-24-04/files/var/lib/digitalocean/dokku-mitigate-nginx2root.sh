#!/bin/bash
# CVE-2026-123007: Dokku nginx-vhosts template adds http2 on TLS when nginx supports it.
set -euo pipefail

DOKKU_TEMPLATE=/var/lib/dokku/core-plugins/available/nginx-vhosts/templates/nginx.conf.sigil
MITIGATE=/var/lib/digitalocean/mitigate-host-nginx-http2.sh

# shellcheck source=/dev/null
source /var/lib/digitalocean/nginx2root-strip-http2.sh

patch_dokku_sigil() {
  local f="${1:?file}"
  [ -f "${f}" ] || return 0
  sed -i 's/{{ if eq $.HTTP2_SUPPORTED "true" }}http2{{ end }}//g' "${f}"
  nginx_strip_http2_from_listen_lines_file "${f}"
}

if [ -f "${DOKKU_TEMPLATE}" ]; then
  patch_dokku_sigil "${DOKKU_TEMPLATE}"
fi

if [ -x "${MITIGATE}" ]; then
  "${MITIGATE}" --restart
fi

if [ -d /home/dokku ] && command -v dokku >/dev/null 2>&1; then
  for app in $(dokku apps:list 2>/dev/null | tail -n +2); do
    [ -n "${app}" ] || continue
    dokku nginx:build-config "${app}" >/dev/null 2>&1 || true
  done
fi

nginx_assert_config_or_die
if systemctl is-active nginx >/dev/null 2>&1; then
  systemctl restart nginx
fi
echo "dokku-mitigate-nginx2root: HTTP/2 disabled for Dokku-managed nginx"