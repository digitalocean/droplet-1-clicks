#!/bin/bash
# After auto-claim fails, signup must stay open so the bootstrap invite can
# create the first admin (Better Auth disableSignUp blocks InviteLanding).
# Poll until a user row exists, then lock public signup.
set -euo pipefail

LOCK_SCRIPT=/opt/lock-paperclip-signup.sh
MAX_ATTEMPTS="${PAPERCLIP_SIGNUP_LOCK_ATTEMPTS:-240}"
SLEEP_SECS="${PAPERCLIP_SIGNUP_LOCK_SLEEP:-30}"

admin_exists() {
  if grep -qE '^PAPERCLIP_AUTH_DISABLE_SIGN_UP=true$' /opt/paperclip.env 2>/dev/null; then
    return 0
  fi
  local url count
  url="$(grep -E '^DATABASE_URL=' /opt/paperclip.env 2>/dev/null | tail -n 1 | cut -d= -f2- || true)"
  [ -n "$url" ] || return 1
  count="$(psql "$url" -tAc 'SELECT COUNT(*) FROM "user"' 2>/dev/null || true)"
  if [ -z "$count" ]; then
    count="$(psql "$url" -tAc 'SELECT COUNT(*) FROM users' 2>/dev/null || true)"
  fi
  count="$(printf '%s' "$count" | tr -d '[:space:]')"
  [ -n "$count" ] && [ "$count" -gt 0 ] 2>/dev/null
}

if [ ! -x "$LOCK_SCRIPT" ]; then
  echo "Missing $LOCK_SCRIPT" >&2
  exit 1
fi

for _ in $(seq 1 "$MAX_ATTEMPTS"); do
  if curl -fsS --max-time 3 "http://127.0.0.1:3100/api/health" >/dev/null 2>&1 && admin_exists; then
    exec "$LOCK_SCRIPT"
  fi
  sleep "$SLEEP_SECS"
done

echo "Timed out waiting for first admin; leaving signup open for invite acceptance." >&2
exit 0
