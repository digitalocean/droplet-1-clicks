#!/bin/bash
# Lightweight checks during image build (Packer). Fails fast if wiring drifts.
set -euo pipefail

: "${application_version:?application_version must be set}"

DOCKERFILE="/var/digitalocean/Dockerfile"

if ! grep -q "quay.io/keycloak/keycloak:${application_version}" "$DOCKERFILE"; then
  echo "regression: Dockerfile must pin Keycloak image to ${application_version}" >&2
  exit 1
fi

if grep -q "KEYCLOAK_VERSION_PLACEHOLDER" "$DOCKERFILE"; then
  echo "regression: Dockerfile still contains KEYCLOAK_VERSION_PLACEHOLDER (01-keycloak.sh ordering?)" >&2
  exit 1
fi

if ! nginx -t >/dev/null 2>&1; then
  echo "regression: nginx -t failed" >&2
  nginx -t
  exit 1
fi

ONBOOT="/var/lib/cloud/scripts/per-instance/001_onboot"
for f in "$ONBOOT" /etc/update-motd.d/99-one-click; do
  if ! bash -n "$f"; then
    echo "regression: bash -n failed for $f" >&2
    exit 1
  fi
done

if ! grep -q 'chmod 600 /root/.digitalocean_passwords' "$ONBOOT"; then
  echo "regression: onboot must chmod 600 /root/.digitalocean_passwords" >&2
  exit 1
fi

for hdr in Host X-Forwarded-Host X-Forwarded-Port X-Forwarded-Proto; do
  if ! grep -q "proxy_set_header ${hdr}" /etc/nginx/sites-available/keycloak; then
    echo "regression: nginx keycloak site missing proxy_set_header ${hdr}" >&2
    exit 1
  fi
done

echo "keycloak-24-04 regression checks ok (image ${application_version})"
