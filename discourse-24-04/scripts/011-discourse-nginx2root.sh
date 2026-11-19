#!/bin/bash
set -euo pipefail

DEBIAN_FRONTEND=noninteractive apt-get -y install python3-yaml >/dev/null 2>&1 || \
  DEBIAN_FRONTEND=noninteractive apt-get -y install python3-yaml

chmod +x /opt/digitalocean_discourse/mitigate-nginx2root.sh
chmod +x /opt/digitalocean_discourse/verify-container-nginx2root.sh
/opt/digitalocean_discourse/mitigate-nginx2root.sh
bash -n /opt/digitalocean_discourse/verify-container-nginx2root.sh

WEB_SSL=/var/discourse/templates/web.ssl.template.yml
if [ -f "${WEB_SSL}" ] && grep -v '^[[:space:]]*#' "${WEB_SSL}" | grep -E 'http2[[:space:]]+on' >/dev/null; then
  echo "ERROR: ${WEB_SSL} still enables http2 on" >&2
  exit 1
fi

for yml in "${WEB_SSL}" /var/discourse/templates/web.letsencrypt.ssl.template.yml; do
  [ -f "${yml}" ] || continue
  python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "${yml}"
done

if [ ! -f /var/discourse/templates/digitalocean-nginx2root.template.yml ]; then
  echo "ERROR: missing DigitalOcean discourse nginx2root template" >&2
  exit 1
fi

python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' \
  /var/discourse/templates/digitalocean-nginx2root.template.yml

if ! grep -q 'digitalocean-nginx2root.template.yml' /var/discourse/samples/standalone.yml; then
  echo "ERROR: samples/standalone.yml must reference digitalocean-nginx2root.template.yml" >&2
  exit 1
fi

DO_TMPL=/var/discourse/templates/digitalocean-nginx2root.template.yml
for needle in \
  '00-digitalocean-http2-off.conf' \
  'digitalocean-nginx2root-apply' \
  'after_ssl'; do
  if ! grep -F "${needle}" "${DO_TMPL}" >/dev/null; then
    echo "ERROR: ${DO_TMPL} missing required ${needle} mitigation" >&2
    exit 1
  fi
done

if grep -v '^[[:space:]]*#' /var/discourse/templates/web.ssl.template.yml \
  | grep -E 'http2[[:space:]]+on' >/dev/null; then
  echo "ERROR: web.ssl.template.yml still contains http2 on" >&2
  exit 1
fi