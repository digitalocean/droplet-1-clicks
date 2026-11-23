#!/bin/bash
# CVE-2026-123007: Dokku nginx-vhosts template adds http2 on TLS when nginx supports it.
set -euo pipefail

MITIGATE=/var/lib/digitalocean/mitigate-host-nginx-http2.sh

# shellcheck source=/dev/null
source /var/lib/digitalocean/nginx2root-strip-http2.sh
# shellcheck source=/dev/null
source /var/lib/digitalocean/dokku-find-nginx-sigil.sh

patch_dokku_sigil() {
  local f="${1:?file}"
  [ -f "${f}" ] || return 0
  sed -i 's/{{ if eq $.HTTP2_SUPPORTED "true" }}http2{{ end }}//g' "${f}"
  nginx_strip_http2_from_listen_lines_file "${f}"
}

patched=0
while IFS= read -r sigil; do
  [ -n "${sigil}" ] || continue
  patch_dokku_sigil "${sigil}"
  patched=1
done < <(dokku_nginx_sigil_candidates | sort -u)

if [ "${patched}" -eq 0 ]; then
  echo "WARN: no Dokku nginx.conf.sigil found to patch" >&2
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