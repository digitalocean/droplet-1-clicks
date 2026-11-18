#!/bin/bash
# CVE-2026-123007: patch discourse_docker templates before first customer bootstrap.
set -euo pipefail

DISCOURSE_ROOT="${DISCOURSE_ROOT:-/var/discourse}"
WEB_SSL_TEMPLATE="${DISCOURSE_ROOT}/templates/web.ssl.template.yml"
LE_SSL_TEMPLATE="${DISCOURSE_ROOT}/templates/web.letsencrypt.ssl.template.yml"
DO_TEMPLATE_SRC=/opt/digitalocean_discourse/templates/digitalocean-nginx2root.template.yml
DO_TEMPLATE_DST="${DISCOURSE_ROOT}/templates/digitalocean-nginx2root.template.yml"

patch_ssl_template_file() {
  local f="${1:?file}"
  [ -f "${f}" ] || return 0
  sed -i \
    -e 's/^\([[:space:]]*\)http2[[:space:]]\+on;/\1http2 off;/g' \
    -e 's/listen 443 ssl http2;/listen 443 ssl;/g' \
    -e 's/listen \[::\]:443 ssl http2;/listen [::]:443 ssl;/g' \
    "${f}"
}

install_do_template() {
  [ -f "${DO_TEMPLATE_SRC}" ] || return 0
  install -d -m 0755 "${DISCOURSE_ROOT}/templates"
  cp -f "${DO_TEMPLATE_SRC}" "${DO_TEMPLATE_DST}"
}

patch_ssl_template_file "${WEB_SSL_TEMPLATE}"
patch_ssl_template_file "${LE_SSL_TEMPLATE}"
install_do_template

patch_discourse_samples() {
  local f="${DISCOURSE_ROOT}/samples/standalone.yml"
  [ -f "${f}" ] || return 0
  if grep -q 'digitalocean-nginx2root.template.yml' "${f}"; then
    return 0
  fi
  python3 - "${f}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
line = '  - "templates/digitalocean-nginx2root.template.yml"\n'
if "digitalocean-nginx2root" in text:
    sys.exit(0)
m = re.search(
    r'^(\s*-\s*"templates/web\.(?:letsencrypt\.)?ssl\.template\.yml"\s*\n)',
    text,
    re.M,
)
if m:
    insert_at = m.end()
    text = text[:insert_at] + line + text[insert_at:]
else:
    block = re.search(r"^templates:\n((?:[ \t#-].*\n)*)", text, re.M)
    if not block:
        print(f"ERROR: could not patch templates list in {path}", file=sys.stderr)
        sys.exit(1)
    insert_at = block.end()
    text = text[:insert_at] + line + text[insert_at:]
path.write_text(text)
PY
}

patch_discourse_samples

if [ -f "${WEB_SSL_TEMPLATE}" ] && grep -v '^[[:space:]]*#' "${WEB_SSL_TEMPLATE}" | grep -E 'http2[[:space:]]+on' >/dev/null; then
  echo "ERROR: ${WEB_SSL_TEMPLATE} still enables http2 on" >&2
  exit 1
fi

echo "discourse mitigate-nginx2root: templates patched (HTTP/2 disabled for HTTPS)"