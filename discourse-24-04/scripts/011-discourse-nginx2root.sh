#!/bin/bash
set -euo pipefail

chmod +x /opt/digitalocean_discourse/mitigate-nginx2root.sh
/opt/digitalocean_discourse/mitigate-nginx2root.sh

WEB_SSL=/var/discourse/templates/web.ssl.template.yml
if [ -f "${WEB_SSL}" ] && grep -v '^[[:space:]]*#' "${WEB_SSL}" | grep -q 'listen 443 ssl http2'; then
  echo "ERROR: ${WEB_SSL} still enables http2" >&2
  exit 1
fi

if [ ! -f /var/discourse/templates/digitalocean-nginx2root.template.yml ]; then
  echo "ERROR: missing DigitalOcean discourse nginx2root template" >&2
  exit 1
fi