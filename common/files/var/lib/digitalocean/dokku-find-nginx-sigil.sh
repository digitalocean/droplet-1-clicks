#!/bin/bash
# Locate Dokku nginx-vhosts sigil template (deb vs source layouts differ).
set -euo pipefail

dokku_nginx_sigil_candidates() {
  local f
  for f in \
    /var/lib/dokku/core-plugins/available/nginx-vhosts/templates/nginx.conf.sigil \
    /var/lib/dokku/plugins/available/nginx-vhosts/templates/nginx.conf.sigil \
    /var/lib/dokku/plugn/plugins/available/nginx-vhosts/templates/nginx.conf.sigil; do
    [ -f "${f}" ] && printf '%s\n' "${f}"
  done
  while IFS= read -r f; do
    printf '%s\n' "${f}"
  done < <(find /var/lib/dokku -path '*/nginx-vhosts/templates/nginx.conf.sigil' 2>/dev/null || true)
}

dokku_nginx_sigil_first() {
  local f
  while IFS= read -r f; do
    [ -n "${f}" ] || continue
    printf '%s' "${f}"
    return 0
  done < <(dokku_nginx_sigil_candidates | sort -u)
  return 1
}