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
SAMPLES=$(require_installed "/var/discourse/samples/standalone.yml")

bash -n "${MITIGATE}"
bash -n "${SETUP}"
# shellcheck source=/dev/null
source "${ALPN_LIB}"

if nginx_config_enables_http2 "${WEB_SSL}"; then
  echo "regression: web.ssl.template.yml must not enable HTTP/2 (listen http2 or http2 on)" >&2
  exit 1
fi

if grep -v '^[[:space:]]*#' "${DO_TEMPLATE}" | grep -E '^[[:space:]]*listen.*http2' >/dev/null; then
  echo "regression: digitalocean template must not add http2 listen lines" >&2
  exit 1
fi

if ! grep -q 'digitalocean-nginx2root.template.yml' "${SAMPLES}"; then
  echo "regression: samples/standalone.yml must list digitalocean-nginx2root.template.yml" >&2
  exit 1
fi

sample_count=$(grep -c 'digitalocean-nginx2root.template.yml' "${SAMPLES}" || true)
if [ "${sample_count}" -gt 1 ]; then
  echo "regression: samples/standalone.yml lists digitalocean template more than once" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  if ! python3 -c 'import yaml' 2>/dev/null; then
    echo "regression: python3-yaml required to validate Discourse templates" >&2
    exit 1
  fi
  for yml in "${WEB_SSL}" "${DO_TEMPLATE}"; do
    python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "${yml}"
  done
  le_ssl=/var/discourse/templates/web.letsencrypt.ssl.template.yml
  if [ -f "${le_ssl}" ]; then
    python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "${le_ssl}"
  fi
fi

echo "discourse-24-04 regression checks ok (CVE-2026-123007 mitigation)"