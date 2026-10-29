#!/bin/bash
# Shared helpers for 001_onboot and /etc/setup_wizard.sh. Source, don't run.

ENV_FILE=/srv/qm/.env

# DigitalOcean Managed Agents sandbox backend's SANDBOX_BACKEND value —
# confirmed from the fork's source (src/deployment/secret-schema.ts) at the
# pinned commit (cf711d04, branch managed-agents-workspace-scratch — the
# fork's formalized naming; an older pinned commit used "mars" literally,
# see README.md "DigitalOcean Managed Agents sandbox backend"). 001_onboot
# and setup_wizard.sh both reference this one constant.
MANAGED_AGENTS_SANDBOX_BACKEND_VALUE="do-managed-agents"

# Default model registered for the DigitalOcean Serverless Inference path —
# https://cloud.digitalocean.com/model-studio/explore-models/model-catalog/deepseek-v4.1-flash
# Context window / max output tokens per DigitalOcean's own docs
# (docs.digitalocean.com/products/gradient-ai-platform/details/models/).
# Overridden at runtime by detect_do_genai_credentials below when present.
DO_INFERENCE_MODEL_ID="deepseek-v4.1-flash"
DO_INFERENCE_MODEL_NAME="DeepSeek V4.1 Flash"
DO_INFERENCE_CONTEXT_WINDOW=1048576
DO_INFERENCE_MAX_TOKENS=1048576

# QM's own custom-model-provider fallback for a model with no explicit
# contextWindow/maxTokens (src/model/custom-providers.ts upstream) — used
# below for an auto-detected model id we have no catalog specs for.
DO_GENERIC_CONTEXT_WINDOW=128000
DO_GENERIC_MAX_TOKENS=8192

# Path DigitalOcean's own GenAI automation drops pre-provisioned Serverless
# Inference credentials at, on droplets created through that flow.
DO_GENAI_CREDENTIALS_FILE="/root/.digitalocean_genai_credentials"

# Reads MODEL_ACCESS_KEY/INFERENCE_MODEL out of DO_GENAI_CREDENTIALS_FILE —
# parsed line by line rather than sourced, even though it's DigitalOcean's
# own file and not arbitrary user input; there's no reason to execute a
# file we didn't write when grep/cut can read it just as well. On success,
# sets DO_GENAI_KEY/DO_GENAI_MODEL and returns 0; returns 1 (leaving both
# unset) if the file is missing or either field is empty.
detect_do_genai_credentials() {
  unset DO_GENAI_KEY DO_GENAI_MODEL
  [ -f "$DO_GENAI_CREDENTIALS_FILE" ] || return 1
  # Trailing whitespace after the closing quote (confirmed present in a
  # real-world file, which corrupted both values with a literal trailing
  # quote and broke model registration downstream) defeats a plain
  # 's/"$//' anchor — trim whitespace and the optional quote together,
  # in either order, so either case is stripped cleanly.
  local key model
  key="$(grep -E '^MODEL_ACCESS_KEY=' "$DO_GENAI_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  model="$(grep -E '^INFERENCE_MODEL=' "$DO_GENAI_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  [ -n "$key" ] && [ -n "$model" ] || return 1
  DO_GENAI_KEY="$key"
  DO_GENAI_MODEL="$model"
  return 0
}

# Reads MANAGED_AGENTS_TOKEN out of the same DO_GENAI_CREDENTIALS_FILE —
# a separate, independent piece of DigitalOcean automation from the model
# credentials above (one droplet may get the model key, the managed-agents
# token, both, or neither — this is why it's its own function rather than
# folded into detect_do_genai_credentials). The token is a DO personal
# access token (dop_v1_...) with agent_harness_session create/read/operate/
# manage/share permissions — exactly the DO_AGENTS_API_TOKEN sandbox-backend
# credential already requires. DigitalOcean's automation also appends this
# same value to /etc/environment, but the credentials file is parsed here
# too (not just sourced from the shell env) for the same reason
# detect_do_genai_credentials parses its file directly: one source of
# truth, read the same way, from both setup_wizard.sh (no /etc/environment
# sourcing of its own) and 001_onboot. On success, sets
# DO_MANAGED_AGENTS_TOKEN and returns 0; returns 1 (leaving it unset) if
# the file is missing or the field is empty.
detect_managed_agents_token() {
  unset DO_MANAGED_AGENTS_TOKEN
  [ -f "$DO_GENAI_CREDENTIALS_FILE" ] || return 1
  local token
  token="$(grep -E '^MANAGED_AGENTS_TOKEN=' "$DO_GENAI_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  [ -n "$token" ] || return 1
  DO_MANAGED_AGENTS_TOKEN="$token"
  return 0
}

# Path DigitalOcean's own automation may drop a pre-provisioned admin
# identity at, on droplets created through a flow that already knows the
# operator's account email (and optionally a password) — a separate piece
# of automation from the GenAI/Managed-Agents credentials file above (one
# droplet may get either, both, or neither).
DO_CUSTOM_INPUTS_FILE="/root/.digitalocean_custom_input"

# Reads EMAIL/PASSWORD out of DO_CUSTOM_INPUTS_FILE — parsed line by line
# rather than sourced, same reasoning as detect_do_genai_credentials above.
# EMAIL must look like an email address (same pattern setup_wizard.sh's own
# interactive prompt enforces) or this returns 1 as if the file were absent
# — unlike the DO-authored genai/dbaas files, this one's EMAIL field has no
# other validation upstream before it reaches here. PASSWORD is optional:
# present but under 12 characters (QM's own minimum) is treated the same as
# absent, leaving DO_CUSTOM_PASSWORD empty for the caller to fall back to a
# generated password, rather than failing the whole detection over a weak
# password when the email half is still usable. On success, sets
# DO_CUSTOM_EMAIL (and DO_CUSTOM_PASSWORD, possibly empty) and returns 0;
# returns 1 (leaving both unset) if the file is missing or EMAIL is absent
# or malformed.
detect_do_custom_inputs() {
  unset DO_CUSTOM_EMAIL DO_CUSTOM_PASSWORD
  [ -f "$DO_CUSTOM_INPUTS_FILE" ] || return 1
  local email password
  email="$(grep -E '^EMAIL=' "$DO_CUSTOM_INPUTS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  password="$(grep -E '^PASSWORD=' "$DO_CUSTOM_INPUTS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  [[ "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || return 1
  DO_CUSTOM_EMAIL="$email"
  DO_CUSTOM_PASSWORD=""
  if [ "${#password}" -ge 12 ]; then
    DO_CUSTOM_PASSWORD="$password"
  fi
  return 0
}

# Path scripts/010-qm.sh saves the deploy-runtime image to at Packer build
# time (built from files/srv/qm/deploy-runtime/Dockerfile) — see
# README.md "Docker-in-Docker for app publishing".
DEPLOY_RUNTIME_IMAGE_TARBALL="/srv/qm/deploy-runtime.tar.gz"

# Loads the deploy-runtime image into dind — QM's own createDockerDeployProvider
# falls back to this image automatically (qm-deploy-runtime:ubuntu24-node20)
# when SANDBOX_BACKEND=do-managed-agents, but dind has its own image cache
# entirely separate from this host's, so building the image at Packer build
# time isn't enough on its own — it has to be loaded into dind specifically,
# which can only happen once dind is actually running (i.e. at boot, not at
# Packer build time). No-op for any other sandbox backend, or if the
# tarball is missing for some reason (non-fatal either way — the deploy
# provider just falls back to its own default image instead, the same as
# if this were never set up at all).
#
# Non-fatal on failure: prints a warning and returns 1 rather than aborting
# the caller, matching register_do_inference_provider's own treatment of a
# non-essential, best-effort post-boot step.
load_deploy_runtime_image() {
  local sandbox_backend="$1"
  [ "$sandbox_backend" = "$MANAGED_AGENTS_SANDBOX_BACKEND_VALUE" ] || return 0
  if [ ! -f "$DEPLOY_RUNTIME_IMAGE_TARBALL" ]; then
    echo "WARNING: ${DEPLOY_RUNTIME_IMAGE_TARBALL} not found — the Ubuntu/Node-20 deploy-runtime image was not loaded into dind; published apps with native npm dependencies may fail to run."
    return 1
  fi

  echo "Waiting for dind to be ready before loading the deploy-runtime image..."
  local attempt
  for attempt in $(seq 1 20); do
    if docker exec qm-dind docker info >/dev/null 2>&1; then
      break
    fi
    if [ "$attempt" = 20 ]; then
      echo "WARNING: dind never became ready — the deploy-runtime image was not loaded. Retry later with: gunzip -c ${DEPLOY_RUNTIME_IMAGE_TARBALL} | docker exec -i qm-dind docker load"
      return 1
    fi
    sleep 3
  done

  echo "Loading the Ubuntu/Node-20 deploy-runtime image into dind (matches the Managed Agents sandbox's own glibc/Node ABI — see README.md)..."
  if ! gunzip -c "$DEPLOY_RUNTIME_IMAGE_TARBALL" | docker exec -i qm-dind docker load; then
    echo "WARNING: loading the deploy-runtime image into dind failed — published apps with native npm dependencies may fail to run."
    return 1
  fi
  return 0
}

# Path DigitalOcean's own Managed Database automation drops pre-provisioned
# connection credentials at, on droplets created with an attached DBaaS
# Postgres (same mechanism django-24-04 in this repo already handles).
DO_DBAAS_CREDENTIALS_FILE="/root/.digitalocean_dbaas_credentials"

# Dedicated app user/database QM gets on the DBaaS cluster, matching the
# names the local bundled Postgres already uses (compose.yml's `postgres`
# service: POSTGRES_USER=POSTGRES_DB=qm) — same convention, different host.
DO_DBAAS_QM_USER="qm"
DO_DBAAS_QM_DATABASE="qm"

# Reads db_protocol/db_host/db_port/db_username/db_password/db_database out
# of DO_DBAAS_CREDENTIALS_FILE — parsed line by line rather than sourced,
# same reasoning as detect_do_genai_credentials above. Only matches
# db_protocol="postgresql" (the file can in principle describe other engine
# types). On success, sets DO_DBAAS_HOST/PORT/ADMIN_USER/ADMIN_PASSWORD/
# ADMIN_DATABASE and returns 0; returns 1 (leaving all unset) if the file is
# missing, isn't postgresql, or any required field is empty. db_database
# defaults to "defaultdb" (DigitalOcean's standard pre-provisioned database
# name) if the file omits it — this is the *admin* bootstrap connection
# target, not the dedicated database QM ends up using (DO_DBAAS_QM_DATABASE
# above), the same distinction django-24-04's own dbaas handling makes.
detect_do_dbaas_credentials() {
  unset DO_DBAAS_HOST DO_DBAAS_PORT DO_DBAAS_ADMIN_USER DO_DBAAS_ADMIN_PASSWORD DO_DBAAS_ADMIN_DATABASE
  [ -f "$DO_DBAAS_CREDENTIALS_FILE" ] || return 1
  local protocol host port user password database
  protocol="$(grep -E '^db_protocol=' "$DO_DBAAS_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  [ "$protocol" = "postgresql" ] || return 1
  host="$(grep -E '^db_host=' "$DO_DBAAS_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  port="$(grep -E '^db_port=' "$DO_DBAAS_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  user="$(grep -E '^db_username=' "$DO_DBAAS_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  password="$(grep -E '^db_password=' "$DO_DBAAS_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  database="$(grep -E '^db_database=' "$DO_DBAAS_CREDENTIALS_FILE" | tail -n 1 | cut -d= -f2- | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  [ -n "$host" ] && [ -n "$port" ] && [ -n "$user" ] && [ -n "$password" ] || return 1
  DO_DBAAS_HOST="$host"
  DO_DBAAS_PORT="$port"
  DO_DBAAS_ADMIN_USER="$user"
  DO_DBAAS_ADMIN_PASSWORD="$password"
  DO_DBAAS_ADMIN_DATABASE="${database:-defaultdb}"
  return 0
}

# Runs one psql statement against the DBaaS cluster as the admin user, via
# an ephemeral postgres:16 container (the same image compose.yml's local
# `postgres` service already uses) rather than a host-installed psql client
# — no new apt package needed. "already exists" is tolerated (not fatal),
# so re-running this on an already-bootstrapped cluster (e.g. the wizard's
# --force) doesn't hard-fail.
dbaas_admin_psql() {
  local sql="$1"
  local out
  if out="$(docker run --rm -e PGPASSWORD="$DO_DBAAS_ADMIN_PASSWORD" postgres:16 \
    psql -h "$DO_DBAAS_HOST" -p "$DO_DBAAS_PORT" -U "$DO_DBAAS_ADMIN_USER" -d "$DO_DBAAS_ADMIN_DATABASE" \
    --set=sslmode=require -v ON_ERROR_STOP=1 -c "$sql" 2>&1)"; then
    return 0
  fi
  if printf '%s' "$out" | grep -qi "already exists"; then
    return 0
  fi
  echo "$out" >&2
  return 1
}

# Waits for the DBaaS cluster to accept connections (it can take a few
# minutes to provision), bootstraps a dedicated qm user + qm database on
# it (idempotent — see dbaas_admin_psql above), and prints a DATABASE_URL
# for that dedicated database. Non-fatal on failure: the caller falls back
# to the local bundled Postgres rather than leaving .env half-configured.
bootstrap_do_dbaas() {
  echo "Waiting for the attached DigitalOcean database to become available (this can take a few minutes)..."
  local attempt
  for attempt in $(seq 1 30); do
    if docker run --rm postgres:16 pg_isready -h "$DO_DBAAS_HOST" -p "$DO_DBAAS_PORT" >/dev/null 2>&1; then
      break
    fi
    if [ "$attempt" = 30 ]; then
      echo "WARNING: the attached database never became reachable — falling back to the local bundled Postgres." >&2
      return 1
    fi
    sleep 5
  done

  local qm_password
  qm_password="$(openssl rand -hex 24)"
  if ! dbaas_admin_psql "CREATE USER ${DO_DBAAS_QM_USER} PASSWORD '${qm_password}';" \
    || ! dbaas_admin_psql "CREATE DATABASE ${DO_DBAAS_QM_DATABASE} OWNER ${DO_DBAAS_QM_USER};" \
    || ! dbaas_admin_psql "GRANT ALL PRIVILEGES ON DATABASE ${DO_DBAAS_QM_DATABASE} TO ${DO_DBAAS_QM_USER};"; then
    echo "WARNING: failed to bootstrap the qm user/database on the attached DigitalOcean database — falling back to the local bundled Postgres." >&2
    return 1
  fi

  # uselibpqcompat=true is required, not cosmetic — confirmed live (core
  # crash-looped without it): node-postgres's pg-connection-string treats
  # sslmode=require as an alias for verify-full, unlike libpq (what psql,
  # and so Django's own dbaas bootstrap, actually use), so without this
  # flag core tries to verify DigitalOcean's managed-database CA chain and
  # fails with "self-signed certificate in certificate chain". This flag
  # restores real libpq semantics for "require": encrypt the connection,
  # don't validate the CA — see the pg warning text this was confirmed
  # against for the exact parameter name.
  DO_DBAAS_URL="postgresql://${DO_DBAAS_QM_USER}:${qm_password}@${DO_DBAAS_HOST}:${DO_DBAAS_PORT}/${DO_DBAAS_QM_DATABASE}?sslmode=require&uselibpqcompat=true"
  return 0
}

write_env_kv() {
  local key="$1" val="$2" tmp="${ENV_FILE}.tmp"
  # Docker Compose interpolates $VAR/${VAR} inside env_file values too, not
  # just inside compose.yml — a literal "$" (e.g. the scrypt hash format's
  # "$"-separated fields in AUTH_PASSWORD_USERS) gets parsed as an unset
  # variable reference and silently deleted. Escape "$" as "$$", Compose's
  # own documented escape, so the container receives the value unmangled.
  val="${val//\$/\$\$}"
  touch "$ENV_FILE"
  grep -v "^${key}=" "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
}

read_env_val() {
  grep -E "^${1}=" "$ENV_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2-
}

env_is_placeholder() {
  case "$(read_env_val "$1")" in
    ""|PLACEHOLDER*) return 0 ;;
    *) return 1 ;;
  esac
}

droplet_ip() {
  curl -fsS --retry 10 --retry-connrefused --max-time 2 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null \
    || hostname -I | awk '{print $1}'
}

# Sends a pre-built signed admin request (the {method,path,body,headers}
# JSON gen-secrets.py prints) to core over `docker exec` — core has no
# published host port, so this reuses curl already installed in its own
# image (deploy/core/Dockerfile). Prints the HTTP status code to stdout;
# the response body (for error reporting) is left at
# /tmp/qm-admin-request.out inside the qm-core container.
send_signed_admin_request() {
  local signed="$1"
  local method path body admin_actor portal_identity ts sig
  method="$(printf '%s' "$signed" | jq -r '.method')"
  path="$(printf '%s' "$signed" | jq -r '.path')"
  body="$(printf '%s' "$signed" | jq -r '.body')"
  admin_actor="$(printf '%s' "$signed" | jq -r '.headers["x-admin-actor"]')"
  portal_identity="$(printf '%s' "$signed" | jq -r '.headers["x-portal-identity"]')"
  ts="$(printf '%s' "$signed" | jq -r '.headers["x-timestamp"]')"
  sig="$(printf '%s' "$signed" | jq -r '.headers["x-signature"]')"

  docker exec \
    -e METHOD="$method" -e REQ_PATH="$path" -e BODY="$body" \
    -e ADMIN_ACTOR="$admin_actor" -e PORTAL_IDENTITY="$portal_identity" \
    -e TS="$ts" -e SIG="$sig" \
    qm-core sh -c '
      curl -sS -o /tmp/qm-admin-request.out -w "%{http_code}" -X "$METHOD" "http://localhost:8080$REQ_PATH" \
        -H "content-type: application/json" \
        -H "x-admin-actor: $ADMIN_ACTOR" \
        -H "x-portal-identity: $PORTAL_IDENTITY" \
        -H "x-timestamp: $TS" \
        -H "x-signature: $SIG" \
        --data-binary "$BODY"
    ' 2>/dev/null
}

# Registers DigitalOcean Serverless Inference as a custom model provider, and
# enables its models in the web UI's chat picker, via core's internal admin
# API — so a curated set of DO's own open-weight models (gen-secrets.py's
# OPEN_SOURCE_MODELS — deliberately excludes the proprietary Anthropic/
# OpenAI-branded models the same endpoint also serves, and per explicit
# product decision every nemotron-* and openai-gpt-oss-* model) is usable
# without any Anthropic/OpenAI key or manual Admin-console step. The model
# detect_do_genai_credentials found (or DO_INFERENCE_MODEL_ID's hardcoded
# fallback) is merged into that catalog rather than replacing it — see
# open_source_models_with_default — and becomes the actual default via
# PI_MODEL (set in 001_onboot/setup_wizard.sh), not through either admin
# call below: neither one has a notion of "default", only "registered" and
# "enabled in the web UI".
#
# Uses the same signed internal-request scheme QM's own `postdeploy-smoke.ts`
# live-session canary uses (src/auth/source-auth-sign.ts +
# src/auth/signed-token.ts) — a plain HMAC-SHA256 request signature plus a
# JWS identity token, both reproduced in gen-secrets.py from
# CORE_SIGNING_SECRET/PORTAL_IDENTITY_SECRET (already generated, already in
# .env).
#
# Two separate admin calls are required, confirmed live on a real droplet:
# registering the provider makes its models resolvable and able to answer
# turns, but the web UI's per-turn model picker is gated by a SEPARATE
# durable allowlist (src/core/turn-options.ts's validateWebTurnModelOptions,
# src/api/app-turn.ts's getWebuiModelsDurable) that defaults to built-in
# models only — without the second call, QM accepts a turn internally but
# the web UI refuses to send it ("that model is not enabled for the web
# UI"). Setting the allowlist to this same model list also closes a side
# effect of the OPENAI_API_KEY bystander credential set in setup_wizard.sh/
# 001_onboot: without it, fake-OpenAI-branded built-ins would otherwise show
# up as selectable in the picker and fail if chosen.
#
# Non-fatal on failure: prints a warning and returns 1 rather than aborting
# the caller, since the stack should still come up even if these steps don't
# land (e.g. a bad key, or core not ready in time).
register_do_inference_provider() {
  local do_key="$1"
  local admin_email core_signing_secret portal_identity_secret org_id
  admin_email="$(read_env_val ADMIN_GRANTS | cut -d: -f1)"
  core_signing_secret="$(read_env_val CORE_SIGNING_SECRET)"
  portal_identity_secret="$(read_env_val PORTAL_IDENTITY_SECRET)"
  org_id="$(read_env_val ORG_ID)"

  echo "Waiting for core to be ready before registering DigitalOcean Serverless Inference..."
  local attempt
  for attempt in $(seq 1 20); do
    if docker exec qm-core curl -fsS --max-time 3 http://localhost:8080/healthz >/dev/null 2>&1; then
      break
    fi
    if [ "$attempt" = 20 ]; then
      echo "WARNING: core never became ready — DigitalOcean Serverless Inference was not registered."
      echo "         Retry later with: sudo /etc/setup_wizard.sh --force"
      return 1
    fi
    sleep 3
  done

  local signed
  if ! signed="$(CORE_SIGNING_SECRET="$core_signing_secret" \
                 PORTAL_IDENTITY_SECRET="$portal_identity_secret" \
                 DO_API_KEY="$do_key" \
                 python3 /srv/qm/gen-secrets.py register-do-inference \
                   "$admin_email" "$org_id" \
                   "$DO_INFERENCE_MODEL_ID" "$DO_INFERENCE_MODEL_NAME" \
                   "$DO_INFERENCE_CONTEXT_WINDOW" "$DO_INFERENCE_MAX_TOKENS")"; then
    echo "WARNING: failed to build the signed registration request — DigitalOcean Serverless Inference was not registered."
    return 1
  fi

  local http_status
  http_status="$(send_signed_admin_request "$signed")" || true
  if [ "$http_status" != "200" ]; then
    echo "WARNING: registering DigitalOcean Serverless Inference failed (HTTP ${http_status:-?})."
    echo "         Check the key, or retry later with: sudo /etc/setup_wizard.sh --force"
    docker exec qm-core sh -c 'cat /tmp/qm-admin-request.out 2>/dev/null' | head -c 500
    return 1
  fi
  echo "DigitalOcean Serverless Inference registered: curated open-weight catalog plus default model ${DO_INFERENCE_MODEL_ID} (actual default is set via PI_MODEL, not this call)."

  local signed2
  if ! signed2="$(CORE_SIGNING_SECRET="$core_signing_secret" \
                  PORTAL_IDENTITY_SECRET="$portal_identity_secret" \
                  python3 /srv/qm/gen-secrets.py set-webui-models \
                    "$admin_email" "$org_id" \
                    "$DO_INFERENCE_MODEL_ID" "$DO_INFERENCE_MODEL_NAME" \
                    "$DO_INFERENCE_CONTEXT_WINDOW" "$DO_INFERENCE_MAX_TOKENS")"; then
    echo "WARNING: failed to build the signed web-UI-enable request — ${DO_INFERENCE_MODEL_ID} may not be selectable in the chat picker yet."
    echo "         Retry later with: sudo /etc/setup_wizard.sh --force"
    return 1
  fi

  local http_status2
  http_status2="$(send_signed_admin_request "$signed2")" || true
  if [ "$http_status2" != "200" ]; then
    echo "WARNING: enabling the DigitalOcean Serverless Inference models (incl. ${DO_INFERENCE_MODEL_ID}) for the web UI chat picker failed (HTTP ${http_status2:-?})."
    echo "         Retry later with: sudo /etc/setup_wizard.sh --force"
    docker exec qm-core sh -c 'cat /tmp/qm-admin-request.out 2>/dev/null' | head -c 500
    return 1
  fi
  return 0
}
