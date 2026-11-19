#!/bin/bash
# Hire the first DigitalOcean OpenCode agent via Paperclip API (no UI injection).
#
# Preconditions: admin already claimed; MODEL_ACCESS_KEY applied
# (/opt/paperclip/.provider-configured). Idempotent when a matching agent exists.
#
# Usage: bootstrap-paperclip-do-agent.sh [public-url]
# Exit 0 when skipped (no inference) or hire already done / succeeded.
# Exit 1 on hard failure when inference was configured.
set -euo pipefail

ENV_FILE=/opt/paperclip.env
CREDS_FILE=/root/paperclip_admin_credentials
SETUP_MARKER=/opt/paperclip/.provider-configured
API_BASE="${PAPERCLIP_CLAIM_API_BASE:-http://127.0.0.1:3100}"
AGENT_NAME="${PAPERCLIP_DO_AGENT_NAME:-DigitalOcean}"
COMPANY_NAME="${PAPERCLIP_DO_COMPANY_NAME:-DigitalOcean}"
OPENCODE_BIN="${PAPERCLIP_OPENCODE_COMMAND:-/usr/local/bin/opencode}"
# Prefer safe defaults; set PAPERCLIP_DO_SKIP_PERMISSIONS=true only if hello-probe fails without it.
SKIP_PERMISSIONS="${PAPERCLIP_DO_SKIP_PERMISSIONS:-false}"

PUBLIC_URL="${1:-}"
if [ -z "$PUBLIC_URL" ]; then
  PUBLIC_URL="$(grep -E '^PAPERCLIP_PUBLIC_URL=' "$ENV_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || true)"
fi
if [ -z "$PUBLIC_URL" ]; then
  pub="$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)"
  ip="${pub:-$(hostname -I | awk '{print $1}')}"
  PUBLIC_URL="https://${ip}"
fi
PUBLIC_URL="${PUBLIC_URL%/}"
PUBLIC_HOST="${PUBLIC_URL#https://}"
PUBLIC_HOST="${PUBLIC_HOST#http://}"
PUBLIC_HOST="${PUBLIC_HOST%%/*}"
API_BASE="${API_BASE%/}"

read_file_kv() {
  local file="$1" key="$2" line val
  [ -f "$file" ] || return 1
  line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1) || return 1
  val="${line#${key}=}"
  val="${val#\"}"; val="${val%\"}"
  val="${val#\'}"; val="${val%\'}"
  printf '%s' "$val"
}

env_value_usable() {
  local v="$1"
  [ -n "$v" ] || return 1
  case "$v" in
    *'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
  esac
  return 0
}

# Soft-skip when inference was never configured.
if [ ! -f "$SETUP_MARKER" ]; then
  echo "Skipping DO agent hire: Serverless Inference is not configured."
  exit 0
fi

MODEL_ACCESS_KEY="$(read_file_kv "$ENV_FILE" MODEL_ACCESS_KEY || true)"
if ! env_value_usable "$MODEL_ACCESS_KEY"; then
  echo "Skipping DO agent hire: MODEL_ACCESS_KEY is not set."
  exit 0
fi

INFERENCE_MODEL="$(read_file_kv "$ENV_FILE" INFERENCE_MODEL || true)"
SMALL_MODEL="$(read_file_kv "$ENV_FILE" PAPERCLIP_OPENCODE_SMALL_MODEL || true)"
if env_value_usable "$SMALL_MODEL"; then
  MODEL_REF="$SMALL_MODEL"
elif env_value_usable "$INFERENCE_MODEL"; then
  case "$INFERENCE_MODEL" in
    digitalocean/*) MODEL_REF="$INFERENCE_MODEL" ;;
    *) MODEL_REF="digitalocean/${INFERENCE_MODEL}" ;;
  esac
else
  echo "ERROR: Inference is marked configured but INFERENCE_MODEL / PAPERCLIP_OPENCODE_SMALL_MODEL is missing." >&2
  exit 1
fi

ADMIN_EMAIL="$(read_file_kv "$CREDS_FILE" ADMIN_EMAIL 2>/dev/null || true)"
INITIAL_PASSWORD="$(read_file_kv "$CREDS_FILE" INITIAL_PASSWORD 2>/dev/null || true)"
if ! env_value_usable "$ADMIN_EMAIL"; then
  ADMIN_EMAIL="$(read_file_kv "$ENV_FILE" ADMIN_EMAIL || true)"
fi
if ! env_value_usable "$INITIAL_PASSWORD"; then
  INITIAL_PASSWORD="$(read_file_kv "$ENV_FILE" INITIAL_PASSWORD || true)"
fi
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@paperclip.local}"
if ! env_value_usable "$INITIAL_PASSWORD"; then
  echo "ERROR: admin password not found in ${CREDS_FILE} or ${ENV_FILE}" >&2
  exit 1
fi

if [ ! -x "$OPENCODE_BIN" ]; then
  if [ -x /opt/ensure-paperclip-opencode.sh ]; then
    /opt/ensure-paperclip-opencode.sh || true
  fi
fi
if [ ! -x "$OPENCODE_BIN" ]; then
  echo "ERROR: ${OPENCODE_BIN} is missing; cannot hire OpenCode agent." >&2
  exit 1
fi

# Wait briefly for API health (post-restart after claim/apply).
HEALTH_OK=0
for _ in $(seq 1 30); do
  if curl -fsS --max-time 2 "${API_BASE}/api/health" >/dev/null 2>&1; then
    HEALTH_OK=1
    break
  fi
  sleep 1
done
if [ "$HEALTH_OK" != "1" ]; then
  echo "ERROR: Paperclip health check failed before DO agent hire." >&2
  exit 1
fi

JAR="$(mktemp)"
BODY="$(mktemp)"
trap 'rm -f "$JAR" "$BODY"' EXIT

# -k only for https:// (shortlived IP certs). Loopback http:// needs no insecure TLS.
curl_api() {
  local method="$1" url="$2" timeout="$3"
  shift 3
  local -a opts=(-sS --max-time "$timeout" -o "$BODY" -w "%{http_code}" -c "$JAR" -b "$JAR"
    -H "Origin: ${PUBLIC_URL}" -H "Referer: ${PUBLIC_URL}/"
    -H "X-Forwarded-Proto: https" -H "X-Forwarded-Host: ${PUBLIC_HOST}")
  case "$url" in
    https://*) opts+=(-k) ;;
  esac
  if [ "$method" = POST ]; then
    opts+=(-H "Content-Type: application/json" -H "Accept: application/json" -X POST --data "$1")
  else
    opts+=(-H "Accept: application/json")
  fi
  curl "${opts[@]}" "$url"
}

post_json() {
  curl_api POST "$1" 60 "$2"
}

get_json() {
  curl_api GET "$1" 30
}

json_signin() {
  python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"password":sys.argv[2]}))' \
    "$ADMIN_EMAIL" "$INITIAL_PASSWORD"
}

try_bases=("$API_BASE")
if [ "$API_BASE" != "$PUBLIC_URL" ]; then
  try_bases+=("$PUBLIC_URL")
fi

AUTH_OK=0
ACTIVE_BASE=""
for base in "${try_bases[@]}"; do
  : >"$JAR"
  HTTP="$(post_json "${base}/api/auth/sign-in/email" "$(json_signin)" || true)"
  if [ "$HTTP" = "200" ] || [ "$HTTP" = "201" ]; then
    AUTH_OK=1
    ACTIVE_BASE="$base"
    echo "Authenticated as ${ADMIN_EMAIL} via ${base}"
    break
  fi
  echo "Sign-in via ${base} failed (HTTP ${HTTP}): $(head -c 300 "$BODY")" >&2
done

if [ "$AUTH_OK" != "1" ]; then
  echo "ERROR: could not sign in as ${ADMIN_EMAIL} for DO agent hire" >&2
  exit 1
fi

# Resolve or create a company.
HTTP="$(get_json "${ACTIVE_BASE}/api/companies?scope=accessible" || true)"
if [ "$HTTP" != "200" ]; then
  HTTP="$(get_json "${ACTIVE_BASE}/api/companies" || true)"
fi
if [ "$HTTP" != "200" ]; then
  echo "ERROR: GET /api/companies failed (HTTP ${HTTP}): $(head -c 400 "$BODY")" >&2
  exit 1
fi

COMPANY_ID="$(
  python3 - <<'PY' "$BODY" "$COMPANY_NAME"
import json, sys
path, want = sys.argv[1], sys.argv[2].strip().lower()
data = json.load(open(path, encoding="utf-8"))
companies = data if isinstance(data, list) else (data.get("companies") if isinstance(data, dict) else None)
if not isinstance(companies, list):
    sys.exit(0)
preferred = None
first = None
for company in companies:
    if not isinstance(company, dict):
        continue
    cid = company.get("id")
    if not isinstance(cid, str) or not cid:
        continue
    if first is None:
        first = cid
    name = company.get("name")
    if isinstance(name, str) and name.strip().lower() == want:
        preferred = cid
        break
print(preferred or first or "", end="")
PY
)"

if [ -z "$COMPANY_ID" ]; then
  CREATE_PAYLOAD="$(
    python3 -c 'import json,sys; print(json.dumps({"name":sys.argv[1]}))' "$COMPANY_NAME"
  )"
  HTTP="$(post_json "${ACTIVE_BASE}/api/companies" "$CREATE_PAYLOAD" || true)"
  if [ "$HTTP" != "200" ] && [ "$HTTP" != "201" ]; then
    echo "ERROR: POST /api/companies failed (HTTP ${HTTP}): $(head -c 400 "$BODY")" >&2
    exit 1
  fi
  COMPANY_ID="$(
    python3 - <<'PY' "$BODY"
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if isinstance(data, dict):
    for key in ("id", "companyId"):
        val = data.get(key)
        if isinstance(val, str) and val:
            print(val, end="")
            raise SystemExit
    company = data.get("company")
    if isinstance(company, dict) and isinstance(company.get("id"), str):
        print(company["id"], end="")
PY
  )"
  if [ -z "$COMPANY_ID" ]; then
    echo "ERROR: company create succeeded but no company id was returned: $(head -c 400 "$BODY")" >&2
    exit 1
  fi
  echo "Created company ${COMPANY_NAME} (${COMPANY_ID})"
else
  echo "Using company ${COMPANY_ID}"
fi

# Idempotent: reuse existing DigitalOcean OpenCode agent when present.
HTTP="$(get_json "${ACTIVE_BASE}/api/companies/${COMPANY_ID}/agents" || true)"
AGENT_ID=""
if [ "$HTTP" = "200" ]; then
  AGENT_ID="$(
    python3 - <<'PY' "$BODY" "$AGENT_NAME" "$MODEL_REF"
import json, sys
path, want_name, want_model = sys.argv[1], sys.argv[2].strip().lower(), sys.argv[3]
data = json.load(open(path, encoding="utf-8"))
agents = data if isinstance(data, list) else (data.get("agents") if isinstance(data, dict) else None)
if not isinstance(agents, list):
    raise SystemExit
for agent in agents:
    if not isinstance(agent, dict):
        continue
    if agent.get("adapterType") != "opencode_local":
        continue
    name = agent.get("name")
    if not isinstance(name, str) or name.strip().lower() != want_name:
        continue
    cfg = agent.get("adapterConfig") if isinstance(agent.get("adapterConfig"), dict) else {}
    model = cfg.get("model") if isinstance(cfg, dict) else ""
    if isinstance(model, str) and model and model != want_model:
        # Same name + adapter is enough for idempotency after a model change.
        pass
    aid = agent.get("id")
    if isinstance(aid, str) and aid:
        print(aid, end="")
        raise SystemExit
PY
  )"
fi

if [ -n "$AGENT_ID" ]; then
  echo "DigitalOcean agent already present (${AGENT_ID}); skipping hire."
else
  HIRE_PAYLOAD="$(
    SKIP_PERMISSIONS="$SKIP_PERMISSIONS" MODEL_REF="$MODEL_REF" OPENCODE_BIN="$OPENCODE_BIN" \
    AGENT_NAME="$AGENT_NAME" python3 - <<'PY'
import json, os
cfg = {
    "model": os.environ["MODEL_REF"],
    "command": os.environ["OPENCODE_BIN"],
}
if os.environ.get("SKIP_PERMISSIONS", "false").lower() in ("1", "true", "yes"):
    cfg["dangerouslySkipPermissions"] = True
print(json.dumps({
    "name": os.environ["AGENT_NAME"],
    "role": "general",
    "adapterType": "opencode_local",
    "runner": "legacy",
    "adapterConfig": cfg,
    "onboardingFirstAgent": True,
    "runtimeConfig": {},
}))
PY
  )"
  HTTP="$(post_json "${ACTIVE_BASE}/api/companies/${COMPANY_ID}/agent-hires" "$HIRE_PAYLOAD" || true)"
  if [ "$HTTP" != "200" ] && [ "$HTTP" != "201" ]; then
    echo "ERROR: agent-hires failed (HTTP ${HTTP}): $(head -c 600 "$BODY")" >&2
    exit 1
  fi

  APPROVAL_ID="$(
    python3 - <<'PY' "$BODY"
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if not isinstance(data, dict):
    raise SystemExit
approval = data.get("approval")
if isinstance(approval, dict):
    aid = approval.get("id")
    if isinstance(aid, str) and aid:
        print(aid, end="")
PY
  )"
  AGENT_ID="$(
    python3 - <<'PY' "$BODY"
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if isinstance(data, dict):
    agent = data.get("agent") if isinstance(data.get("agent"), dict) else data
    if isinstance(agent, dict):
        aid = agent.get("id")
        if isinstance(aid, str) and aid:
            print(aid, end="")
            raise SystemExit
    for key in ("agentId", "id"):
        val = data.get(key)
        if isinstance(val, str) and val:
            print(val, end="")
            raise SystemExit
PY
  )"

  if [ -n "$APPROVAL_ID" ]; then
    APPROVE_PAYLOAD='{"decisionNote":"Approved during DigitalOcean first-boot agent bootstrap."}'
    HTTP="$(post_json "${ACTIVE_BASE}/api/approvals/${APPROVAL_ID}/approve" "$APPROVE_PAYLOAD" || true)"
    if [ "$HTTP" != "200" ] && [ "$HTTP" != "201" ]; then
      echo "ERROR: approval failed (HTTP ${HTTP}): $(head -c 400 "$BODY")" >&2
      exit 1
    fi
    echo "Approved hire ${APPROVAL_ID}"
  fi

  if [ -z "$AGENT_ID" ]; then
    echo "ERROR: hire succeeded but no agent id was returned: $(head -c 400 "$BODY")" >&2
    exit 1
  fi
  echo "Hired DigitalOcean agent ${AGENT_ID} (model ${MODEL_REF})"
fi

# Resume + poll until ready (verification is async).
resume_agent() {
  local aid="$1"
  post_json "${ACTIVE_BASE}/api/agents/${aid}/resume?companyId=${COMPANY_ID}" '{}' >/dev/null || true
}

agent_state() {
  local aid="$1"
  HTTP="$(get_json "${ACTIVE_BASE}/api/companies/${COMPANY_ID}/agents" || true)"
  [ "$HTTP" = "200" ] || return 1
  python3 - <<'PY' "$BODY" "$aid"
import json, sys
path, want = sys.argv[1], sys.argv[2]
data = json.load(open(path, encoding="utf-8"))
agents = data if isinstance(data, list) else (data.get("agents") if isinstance(data, dict) else None)
if not isinstance(agents, list):
    print("missing")
    raise SystemExit
agent = next((a for a in agents if isinstance(a, dict) and a.get("id") == want), None)
if not agent:
    print("missing")
    raise SystemExit
lifecycle = (agent.get("lifecycleState") or "").lower()
legacy = (agent.get("status") or "").lower()
detail = " ".join(
    str(agent.get(k) or "") for k in ("lifecycleError", "lastError", "statusMessage", "verificationError")
).lower()
if lifecycle in ("ready", "running", "idle") or (not lifecycle and legacy in ("active", "running", "idle")):
    print("ready")
elif "fail" in lifecycle or lifecycle == "error" or ("verification" in detail and "fail" in detail) or "execution configuration" in detail:
    print("failed")
elif lifecycle == "paused" or (not lifecycle and legacy == "paused"):
    print("paused")
else:
    print("pending")
PY
}

RESUMED=0
READY=0
for _ in $(seq 1 60); do
  STATE="$(agent_state "$AGENT_ID" || echo missing)"
  case "$STATE" in
    ready)
      READY=1
      break
      ;;
    failed)
      echo "WARNING: DigitalOcean agent verification failed. On the Droplet run:" >&2
      echo "  sudo /opt/ensure-paperclip-opencode.sh && sudo /opt/apply-inference-from-env.sh && sudo systemctl restart paperclip" >&2
      echo "  sudo /opt/bootstrap-paperclip-do-agent.sh" >&2
      echo "Then open the agent in the dashboard and click Retry now." >&2
      # Hire itself succeeded; leave agent for operator retry.
      exit 0
      ;;
    paused)
      if [ "$RESUMED" = "0" ]; then
        resume_agent "$AGENT_ID"
        RESUMED=1
      fi
      ;;
  esac
  sleep 2
done

if [ "$READY" = "1" ]; then
  echo "DigitalOcean agent is ready (${AGENT_ID})."
  exit 0
fi

echo "WARNING: DigitalOcean agent ${AGENT_ID} is still verifying after bootstrap." >&2
echo "Open the dashboard agent page and click Retry if needed, or re-run:" >&2
echo "  sudo /opt/bootstrap-paperclip-do-agent.sh" >&2
exit 0
