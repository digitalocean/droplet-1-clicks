#!/bin/bash
# CVE-2026-123007: patch discourse_docker templates and app.yml for HTTP/1.1-only HTTPS.
set -euo pipefail

DISCOURSE_ROOT="${DISCOURSE_ROOT:-/var/discourse}"
WEB_SSL_TEMPLATE="${DISCOURSE_ROOT}/templates/web.ssl.template.yml"
DO_TEMPLATE_SRC=/opt/digitalocean_discourse/templates/digitalocean-nginx2root.template.yml
DO_TEMPLATE_DST="${DISCOURSE_ROOT}/templates/digitalocean-nginx2root.template.yml"
APP_YML="${DISCOURSE_ROOT}/containers/app.yml"
TEMPLATE_LINE='  - "templates/digitalocean-nginx2root.template.yml"'

patch_web_ssl_template() {
  local f="${WEB_SSL_TEMPLATE}"
  [ -f "${f}" ] || return 0
  sed -i \
    -e 's/listen 443 ssl http2;/listen 443 ssl;/g' \
    -e 's/listen \[::\]:443 ssl http2;/listen [::]:443 ssl;/g' \
    "${f}"
}

install_do_template() {
  [ -f "${DO_TEMPLATE_SRC}" ] || return 0
  install -d -m 0755 "${DISCOURSE_ROOT}/templates"
  cp -f "${DO_TEMPLATE_SRC}" "${DO_TEMPLATE_DST}"
}

inject_app_yml_template() {
  local f="${APP_YML}"
  [ -f "${f}" ] || return 0
  if grep -q 'digitalocean-nginx2root.template.yml' "${f}"; then
    return 0
  fi
  if grep -q 'web.ssl.template.yml\|web.letsencrypt.ssl.template.yml' "${f}"; then
    sed -i "/web\.\(ssl\|letsencrypt\.ssl\)\.template\.yml/a\\ ${TEMPLATE_LINE}" "${f}"
  else
    sed -i "/^templates:/a\\ ${TEMPLATE_LINE}" "${f}"
  fi
}

main() {
  patch_web_ssl_template
  install_do_template
  inject_app_yml_template
  echo "discourse mitigate-nginx2root: templates patched (HTTP/2 disabled for HTTPS)"
}

main "$@"