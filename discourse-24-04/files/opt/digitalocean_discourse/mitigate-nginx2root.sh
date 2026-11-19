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

patch_web_templates_http_listeners() {
  local web_template="${DISCOURSE_ROOT}/templates/web.template.yml"
  local web_ssl="${DISCOURSE_ROOT}/templates/web.ssl.template.yml"
  [ -f "${web_template}" ] || return 0
  if grep -F 'http2 off' "${web_template}" >/dev/null 2>&1; then
    :
  else
    sed -i \
      -e 's/echo "listen 80;\\nlisten \[::\]:80;"/echo -e "listen 80;\\nlisten [::]:80;\\nhttp2 off;"/' \
      "${web_template}"
  fi
  if [ -f "${web_ssl}" ]; then
    python3 - "${web_ssl}" <<'PY'
import re
import sys
from pathlib import Path


def server_block_at(text: str, idx: int) -> tuple[int, int] | None:
    start = text.rfind("server {", 0, idx)
    if start < 0:
        return None
    depth = 0
    j = start
    while j < len(text):
        if text.startswith("server {", j):
            depth += 1
            j += len("server {")
            continue
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return start, j + 1
        j += 1
    return None


path = Path(sys.argv[1])
text = path.read_text()
needle = "return 301 https"
idx = text.find(needle)
if idx < 0:
    sys.exit(0)
span = server_block_at(text, idx)
if not span:
    sys.exit(0)
start, end = span
block = text[start:end]
if re.search(r"^[ \t]*http2[ \t]+(on|off)\s*;", block, re.M):
    sys.exit(0)
listen_v6 = re.search(r"^([ \t]*)listen \[::\]:80;\s*$", block, re.M)
if not listen_v6:
    sys.exit(0)
indent = listen_v6.group(1)
insert = f"{listen_v6.group(0)}\n{indent}http2 off;"
block_new = block[: listen_v6.start()] + insert + block[listen_v6.end() :]
path.write_text(text[:start] + block_new + text[end:])
PY
  fi
}

install_do_template() {
  [ -f "${DO_TEMPLATE_SRC}" ] || return 0
  install -d -m 0755 "${DISCOURSE_ROOT}/templates"
  cp -f "${DO_TEMPLATE_SRC}" "${DO_TEMPLATE_DST}"
}

patch_ssl_template_file "${WEB_SSL_TEMPLATE}"
patch_ssl_template_file "${LE_SSL_TEMPLATE}"
patch_web_templates_http_listeners
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

if [ -x /opt/digitalocean_discourse/discourse-template-nginx2root-checks.py ]; then
  python3 /opt/digitalocean_discourse/discourse-template-nginx2root-checks.py \
    "${WEB_SSL_TEMPLATE}" "${LE_SSL_TEMPLATE}"
fi

echo "discourse mitigate-nginx2root: templates patched (HTTP/2 disabled on :80/:443)"