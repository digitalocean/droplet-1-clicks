#!/bin/bash
set -euo pipefail

require_installed() {
  local f=$1
  if [ ! -f "${f}" ]; then
    echo "regression: missing ${f}" >&2
    exit 1
  fi
  printf '%s' "${f}"
}

ALPN_LIB=$(require_installed "/var/lib/digitalocean/nginx2root-alpn-check.sh")
MITIGATE=$(require_installed "/opt/digitalocean_discourse/mitigate-nginx2root.sh")
SETUP=$(require_installed "/opt/digitalocean_discourse/setup_discourse.sh")
WEB_SSL=$(require_installed "/var/discourse/templates/web.ssl.template.yml")
DO_TEMPLATE=$(require_installed "/var/discourse/templates/digitalocean-nginx2root.template.yml")

bash -n "${MITIGATE}"
bash -n "${SETUP}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"

if nginx_site_listens_with_http2 "${WEB_SSL}"; then
  echo "regression: web.ssl.template.yml must not use listen … http2" >&2
  exit 1
fi

if grep -v '^[[:space:]]*#' "${DO_TEMPLATE}" | grep -qE '^[[:space:]]*listen.*http2'; then
  echo "regression: digitalocean template must not add http2 listen lines" >&2
  exit 1
fi

echo "discourse-24-04 regression checks ok (CVE-2026-123007 mitigation)"