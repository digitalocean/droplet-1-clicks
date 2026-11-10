#!/bin/bash
# Lightweight checks during image build (Packer). Fails fast if wiring drifts.
# Comment lines and end-of-line # comments are ignored for textual safety checks.
set -euo pipefail

: "${application_version:?application_version must be set}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
KEYCLOAK_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# Packer guest paths; fall back to repo layout for local/CI without /var digitalocean tree.
DEFAULT_DOCKERFILE="/var/digitalocean/Dockerfile"
DEFAULT_ONBOOT="/var/lib/cloud/scripts/per-instance/001_onboot"
DEFAULT_MOTD="/etc/update-motd.d/99-one-click"
DEFAULT_NGX="/etc/nginx/sites-available/keycloak"

resolve_file() {
  local primary=$1
  local alt=$2
  if [ -f "$primary" ]; then
    printf '%s' "$primary"
  elif [ -n "$alt" ] && [ -f "$alt" ]; then
    printf '%s' "$alt"
  else
    echo "regression: missing file (expected $primary or $alt)" >&2
    exit 1
  fi
}

DOCKERFILE=$(resolve_file "$DEFAULT_DOCKERFILE" "$KEYCLOAK_DIR/files/var/digitalocean/Dockerfile")
ONBOOT=$(resolve_file "$DEFAULT_ONBOOT" "$KEYCLOAK_DIR/files/var/lib/cloud/scripts/per-instance/001_onboot")
MOTD=$(resolve_file "$DEFAULT_MOTD" "$KEYCLOAK_DIR/files/etc/update-motd.d/99-one-click")
NGX=$(resolve_file "$DEFAULT_NGX" "$KEYCLOAK_DIR/files/etc/nginx/sites-available/keycloak")

# Remove bash/sh comments (# to EOL) for semantic greps only.
strip_shell_comments() {
  awk '{ sub(/#.*/, ""); print }' "$1"
}

# Unsafe: docker -e KC_PROXY_HEADERS=... (real env injection). Safe: same text only in comments.
onboot_sets_kc_proxy_headers() {
  strip_shell_comments "$1" | grep -qE '(^|[[:space:]])-e[[:space:]]+KC_PROXY_HEADERS='
}

onboot_full_exec_to_setup_log() {
  strip_shell_comments "$1" | grep -qE '^[[:space:]]*exec[[:space:]].*one_click_setup\.log'
}

run_regression_checks() {
  local df_resolved
  df_resolved=$DOCKERFILE
  if grep -q KEYCLOAK_VERSION_PLACEHOLDER "$DOCKERFILE"; then
    df_resolved=$(mktemp)
    trap 'rm -f "${df_resolved:-}" 2>/dev/null || true' EXIT
    sed "s|KEYCLOAK_VERSION_PLACEHOLDER|${application_version}|g" "$DOCKERFILE" >"$df_resolved"
  fi

  if ! grep -q "quay.io/keycloak/keycloak:${application_version}" "$df_resolved"; then
    echo "regression: Dockerfile must pin Keycloak image to ${application_version}" >&2
    return 1
  fi

  if grep -q "KEYCLOAK_VERSION_PLACEHOLDER" "$df_resolved"; then
    echo "regression: Dockerfile still contains KEYCLOAK_VERSION_PLACEHOLDER after substitute" >&2
    return 1
  fi

  if [ -f /etc/nginx/nginx.conf ]; then
    if ! nginx -t >/dev/null 2>&1; then
      echo "regression: nginx -t failed" >&2
      nginx -t
      return 1
    fi
  else
    echo "regression: skipping nginx -t (no /etc/nginx/nginx.conf — not a full image env)"
  fi

  if ! bash -n "$ONBOOT"; then
    echo "regression: bash -n failed for $ONBOOT" >&2
    return 1
  fi
  if ! sh -n "$MOTD"; then
    echo "regression: sh -n failed for $MOTD" >&2
    return 1
  fi

  if ! grep -q 'return 302 https://$host:8443$request_uri' "$NGX"; then
    echo "regression: nginx :80 must redirect to https://\$host:8443 (TLS for admin traffic)" >&2
    return 1
  fi
  if ! grep -q 'location ~ /.well-known' "$NGX"; then
    echo "regression: nginx must expose /.well-known for certbot" >&2
    return 1
  fi

  if onboot_sets_kc_proxy_headers "$ONBOOT"; then
    echo "regression: onboot must not pass -e KC_PROXY_HEADERS=... (direct :8443 exposed; comments are ok)" >&2
    return 1
  fi
  if onboot_full_exec_to_setup_log "$ONBOOT"; then
    echo "regression: onboot must not redirect all output to setup log (sensitive traces)" >&2
    return 1
  fi
  if ! grep -q 'umask 077' "$ONBOOT"; then
    echo "regression: onboot must set umask 077 before writing secrets" >&2
    return 1
  fi
  if ! grep -q 'install -m 600' "$ONBOOT" || ! grep -q '/var/log/one_click_setup.log' "$ONBOOT"; then
    echo "regression: onboot must create /var/log/one_click_setup.log as 600 via install" >&2
    return 1
  fi
  if strip_shell_comments "$ONBOOT" | grep -qE 'chmod[[:space:]]+(600|400)[[:space:]]+/root/\.digitalocean_passwords'; then
    echo "regression: passwords file must rely on umask (no post-hoc chmod that implies a bad default mode)" >&2
    return 1
  fi

  # Behavioral check: under umask 077, a new root-owned file is 600 and inaccessible to group/other.
  local tmpfile
  tmpfile=$(mktemp /tmp/keycloak-regression-umask.XXXXXX)
  rm -f "$tmpfile"
  umask 077
  echo test >"$tmpfile"
  local perm
  perm=$(stat -c '%a' "$tmpfile")
  rm -f "$tmpfile"
  if [ "$perm" != "600" ]; then
    echo "regression: expected umask 077 to yield 600 file, got ${perm}" >&2
    return 1
  fi

  echo "keycloak-24-04 regression checks ok (image ${application_version})"
  return 0
}

run_selftest() {
  local failures=0
  local tdir d good bad

  tdir=$(mktemp -d)
  trap 'rm -rf "$tdir"' RETURN

  # Fixture: comment mentions KC_PROXY_HEADERS but no -e assignment — must PASS
  good="$tdir/onboot-good.sh"
  cat >"$good" <<'GOOD'
#!/bin/bash
umask 077
install -m 600 -o root -g root /dev/null /var/log/one_click_setup.log
# Do not set KC_PROXY_HEADERS: port 8443 exposed
docker run -d \
  -e KEYCLOAK_ADMIN=admin \
  image
GOOD

  # Fixture: real docker env — must FAIL detection when we expect unsafe
  bad="$tdir/onboot-bad.sh"
  cat >"$bad" <<'BAD'
#!/bin/bash
docker run \
  -e KC_PROXY_HEADERS=xforwarded \
  image
BAD

  if onboot_sets_kc_proxy_headers "$good"; then
    echo "selftest FAIL: good fixture (comment only) flagged as KC_PROXY_HEADERS set" >&2
    failures=$((failures + 1))
  else
    echo "selftest OK: comment-only KC_PROXY_HEADERS not treated as assignment"
  fi

  if ! onboot_sets_kc_proxy_headers "$bad"; then
    echo "selftest FAIL: bad fixture (-e KC_PROXY_HEADERS=) not detected" >&2
    failures=$((failures + 1))
  else
    echo "selftest OK: -e KC_PROXY_HEADERS= detected"
  fi

  # exec: comment must not false-positive
  d="$tdir/exec-pass.sh"
  printf '%s\n' '# exec >>/var/log/one_click_setup.log 2>&1' 'echo ok' >"$d"
  if onboot_full_exec_to_setup_log "$d"; then
    echo "selftest FAIL: commented exec should not match" >&2
    failures=$((failures + 1))
  else
    echo "selftest OK: commented exec line ignored"
  fi

  d="$tdir/exec-fail.sh"
  printf '%s\n' 'exec >>/var/log/one_click_setup.log 2>&1' >"$d"
  if ! onboot_full_exec_to_setup_log "$d"; then
    echo "selftest FAIL: real exec redirect should match" >&2
    failures=$((failures + 1))
  else
    echo "selftest OK: real exec redirect detected"
  fi

  if [ "$failures" -ne 0 ]; then
    echo "selftest: $failures failure(s)" >&2
    return 1
  fi
  echo "keycloak-24-04 regression selftest: all cases passed"
  return 0
}

if [ "${KEYCLOAK_REGRESSION_SELFTEST:-}" = 1 ]; then
  run_selftest
  exit $?
fi

run_regression_checks
exit $?
