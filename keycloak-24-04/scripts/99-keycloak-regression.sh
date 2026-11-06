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
MOTD="/etc/update-motd.d/99-one-click"

if ! bash -n "$ONBOOT"; then
  echo "regression: bash -n failed for $ONBOOT" >&2
  exit 1
fi
if ! sh -n "$MOTD"; then
  echo "regression: sh -n failed for $MOTD" >&2
  exit 1
fi

NGX="/etc/nginx/sites-available/keycloak"
if ! grep -q 'return 302 https://$host:8443$request_uri' "$NGX"; then
  echo "regression: nginx :80 must redirect to https://\$host:8443 (TLS for admin traffic)" >&2
  exit 1
fi
if ! grep -q 'location ~ /.well-known' "$NGX"; then
  echo "regression: nginx must expose /.well-known for certbot" >&2
  exit 1
fi
if grep -q 'KC_PROXY_HEADERS' "$ONBOOT"; then
  echo "regression: onboot must not set KC_PROXY_HEADERS (direct :8443 exposed)" >&2
  exit 1
fi
if grep -q 'exec.*one_click_setup.log' "$ONBOOT"; then
  echo "regression: onboot must not redirect all output to setup log (sensitive traces)" >&2
  exit 1
fi
if ! grep -q 'umask 077' "$ONBOOT"; then
  echo "regression: onboot must set umask 077 before writing secrets" >&2
  exit 1
fi
if ! grep -q 'install -m 600' "$ONBOOT" || ! grep -q '/var/log/one_click_setup.log' "$ONBOOT"; then
  echo "regression: onboot must create /var/log/one_click_setup.log as 600 via install" >&2
  exit 1
fi
if grep -qE 'chmod[[:space:]]+(600|400).*digitalocean_passwords' "$ONBOOT"; then
  echo "regression: passwords file must rely on umask (no post-hoc chmod that implies a bad default mode)" >&2
  exit 1
fi

# Behavioral check: under umask 077, a new root-owned file is 600 and inaccessible to group/other.
tmpfile=$(mktemp /tmp/keycloak-regression-umask.XXXXXX)
rm -f "$tmpfile"
umask 077
echo test >"$tmpfile"
perm=$(stat -c '%a' "$tmpfile")
rm -f "$tmpfile"
if [ "$perm" != "600" ]; then
  echo "regression: expected umask 077 to yield 600 file, got ${perm}" >&2
  exit 1
fi

echo "keycloak-24-04 regression checks ok (image ${application_version})"
