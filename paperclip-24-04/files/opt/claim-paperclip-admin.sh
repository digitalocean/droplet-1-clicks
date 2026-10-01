#!/bin/bash
# Claim Paperclip first admin: sign-up → bootstrap-ceo invite → accept → verify.
#
# Usage: claim-paperclip-admin.sh <public-url> <email> <password> [display-name]
# Prints INVITE_URL=<url> on success.
set -euo pipefail

PUBLIC_URL="${1:-}"
EMAIL="${2:-}"
PASSWORD="${3:-}"
NAME="${4:-Admin}"
INVITE_FILE="${INVITE_FILE:-/root/paperclip_bootstrap_invite.txt}"
# Prefer loopback for API calls (same process network as paperclip); public URL
# is still sent as Origin so Better Auth trusted-origins checks pass.
API_BASE="${PAPERCLIP_CLAIM_API_BASE:-http://127.0.0.1:3100}"

if [ -z "$PUBLIC_URL" ] || [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: $0 <public-url> <email> <password> [display-name]" >&2
  exit 1
fi

PUBLIC_URL="${PUBLIC_URL%/}"
API_BASE="${API_BASE%/}"
PUBLIC_HOST="${PUBLIC_URL#https://}"
PUBLIC_HOST="${PUBLIC_HOST#http://}"
PUBLIC_HOST="${PUBLIC_HOST%%/*}"

JAR="$(mktemp)"
BODY="$(mktemp)"
trap 'rm -f "$JAR" "$BODY"' EXIT

post_json() {
  local url="$1" data="$2"
  # -k covers shortlived TLS when API_BASE is the public https URL
  curl -sS -k --max-time 30 \
    -o "$BODY" -w "%{http_code}" \
    -c "$JAR" -b "$JAR" \
    -H "Content-Type: application/json" \
    -H "Origin: ${PUBLIC_URL}" \
    -H "Referer: ${PUBLIC_URL}/" \
    -H "X-Forwarded-Proto: https" \
    -H "X-Forwarded-Host: ${PUBLIC_HOST}" \
    -X POST "$url" \
    --data "$data"
}

get_json() {
  local url="$1"
  curl -sS -k --max-time 30 \
    -o "$BODY" -w "%{http_code}" \
    -c "$JAR" -b "$JAR" \
    -H "Accept: application/json" \
    -H "Origin: ${PUBLIC_URL}" \
    -H "Referer: ${PUBLIC_URL}/" \
    -H "X-Forwarded-Proto: https" \
    -H "X-Forwarded-Host: ${PUBLIC_HOST}" \
    "$url"
}

json_signup() {
  python3 -c 'import json,sys; print(json.dumps({"name":sys.argv[1],"email":sys.argv[2],"password":sys.argv[3]}))' \
    "$NAME" "$EMAIL" "$PASSWORD"
}

json_signin() {
  python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"password":sys.argv[2]}))' \
    "$EMAIL" "$PASSWORD"
}

body_has_bootstrap_accepted() {
  python3 - <<'PY' "$BODY"
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    sys.exit(1)
sys.exit(0 if isinstance(data, dict) and "bootstrapAccepted" in data else 1)
PY
}

bootstrap_status_ready() {
  python3 - <<'PY' "$BODY"
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    sys.exit(1)
sys.exit(0 if isinstance(data, dict) and data.get("bootstrapStatus") == "ready" else 1)
PY
}

# Try loopback first; if that fails auth/origin checks, fall back to public URL.
try_bases=("$API_BASE")
if [ "$API_BASE" != "$PUBLIC_URL" ]; then
  try_bases+=("$PUBLIC_URL")
fi

AUTH_OK=0
ACTIVE_BASE=""
for base in "${try_bases[@]}"; do
  : >"$JAR"
  HTTP="$(post_json "${base}/api/auth/sign-up/email" "$(json_signup)" || true)"
  if [ "$HTTP" != "200" ] && [ "$HTTP" != "201" ]; then
    HTTP="$(post_json "${base}/api/auth/sign-in/email" "$(json_signin)" || true)"
  fi
  if [ "$HTTP" = "200" ] || [ "$HTTP" = "201" ]; then
    AUTH_OK=1
    ACTIVE_BASE="$base"
    echo "Authenticated via ${base} (HTTP ${HTTP})"
    break
  fi
  echo "Auth via ${base} failed (HTTP ${HTTP}): $(head -c 300 "$BODY")" >&2
done

if [ "$AUTH_OK" != "1" ]; then
  echo "ERROR: could not sign up or sign in as ${EMAIL}" >&2
  exit 1
fi

# Mint bootstrap CEO invite
BOOTSTRAP_OUT="$(su - paperclip -c "paperclipai auth bootstrap-ceo --base-url ${PUBLIC_URL}" 2>&1 || true)"
BOOTSTRAP_CLEAN="$(printf '%s\n' "$BOOTSTRAP_OUT" | sed $'s/\033\\[[0-9;]*[[:alpha:]]//g')"

# Prefer token form used by upstream smoke/operator scripts
TOKEN="$(printf '%s\n' "$BOOTSTRAP_CLEAN" | grep -oE 'pcp_bootstrap_[a-fA-F0-9]+' | head -n 1 || true)"
INVITE_URL=""
if [ -n "$TOKEN" ]; then
  INVITE_URL="${PUBLIC_URL}/invite/${TOKEN}"
else
  INVITE_URL="$(printf '%s\n' "$BOOTSTRAP_CLEAN" | grep -oE 'https://[^[:space:]]+/invite/[^[:space:]]+' | head -n 1 || true)"
  TOKEN="$(printf '%s' "$INVITE_URL" | sed -n 's|.*/invite/\([^/?#[:space:]]*\).*|\1|p')"
fi

if [ -z "$TOKEN" ] || [ -z "$INVITE_URL" ]; then
  if printf '%s\n' "$BOOTSTRAP_CLEAN" | grep -qi 'already has an admin'; then
    # May already be claimed — verify below after a fresh sign-in session
    echo "bootstrap-ceo reports an admin already exists; verifying session access..."
  else
    echo "ERROR: bootstrap-ceo did not print an invite token" >&2
    printf '%s\n' "$BOOTSTRAP_OUT" >&2
    exit 1
  fi
else
  printf '%s\n' "$INVITE_URL" > "$INVITE_FILE"
  chmod 600 "$INVITE_FILE"

  HTTP="$(post_json "${ACTIVE_BASE}/api/invites/${TOKEN}/accept" '{"requestType":"human"}' || true)"
  if [ "$HTTP" != "200" ] && [ "$HTTP" != "201" ]; then
    echo "ERROR: invite accept failed (HTTP ${HTTP}): $(head -c 400 "$BODY")" >&2
    exit 1
  fi
  if ! body_has_bootstrap_accepted; then
    echo "ERROR: invite accept HTTP ${HTTP} but response missing bootstrapAccepted: $(head -c 400 "$BODY")" >&2
    exit 1
  fi
  echo "Bootstrap invite accepted (bootstrapAccepted present)."
fi

# Verify the signed-in board session can access the instance
HTTP="$(get_json "${ACTIVE_BASE}/api/health" || true)"
if [ "$HTTP" = "200" ] && bootstrap_status_ready; then
  echo "Health reports bootstrapStatus=ready."
else
  # Some builds omit bootstrapStatus on anonymous health; check companies instead
  HTTP="$(get_json "${ACTIVE_BASE}/api/companies" || true)"
  if [ "$HTTP" != "200" ] || ! python3 -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); sys.exit(0 if isinstance(d,list) else 1)' "$BODY"; then
    echo "ERROR: admin claim did not grant board access (companies HTTP ${HTTP}): $(head -c 400 "$BODY")" >&2
    echo "Signed-in user exists but is not instance-admin / has no org access." >&2
    exit 1
  fi
  echo "Board companies endpoint OK after claim."
fi

if [ -n "$INVITE_URL" ]; then
  echo "INVITE_URL=${INVITE_URL}"
fi
echo "Paperclip admin claimed for ${EMAIL}"
exit 0
