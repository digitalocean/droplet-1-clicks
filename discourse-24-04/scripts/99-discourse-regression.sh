#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DISCOURSE_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
ALPN_LIB="${DISCOURSE_DIR}/../common/files/var/lib/digitalocean/nginx2root-alpn-check.sh"
MITIGATE=/opt/digitalocean_discourse/mitigate-nginx2root.sh
WEB_SSL=/var/discourse/templates/web.ssl.template.yml
DO_TEMPLATE=/var/discourse/templates/digitalocean-nginx2root.template.yml
SETUP=/opt/digitalocean_discourse/setup_discourse.sh

for f in "${ALPN_LIB}" "${MITIGATE}" "${SETUP}"; do
  if [ ! -f "${f}" ]; then
    echo "regression: missing ${f}" >&2
    exit 1
  fi
done

bash -n "${MITIGATE}"
bash -n "${SETUP}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"

if [ ! -f "${WEB_SSL}" ]; then
  echo "regression: discourse_docker clone missing web.ssl.template.yml" >&2
  exit 1
fi

if nginx_site_listens_with_http2 "${WEB_SSL}"; then
  echo "regression: web.ssl.template.yml must not use listen … http2" >&2
  exit 1
fi

if [ ! -f "${DO_TEMPLATE}" ]; then
  echo "regression: missing ${DO_TEMPLATE}" >&2
  exit 1
fi

if grep -v '^[[:space:]]*#' "${DO_TEMPLATE}" | grep -qE 'listen.*http2'; then
  echo "regression: digitalocean template must not add http2 listen lines" >&2
  exit 1
fi

echo "discourse-24-04 regression checks ok (CVE-2026-123007 mitigation)"