#!/bin/bash
# Retries Serverless Inference apply after cloud-init may have written MODEL_ACCESS_KEY.
# When apply succeeds and an admin was already claimed, also hire the DO agent.
set -euo pipefail

MARKER=/opt/paperclip/.provider-configured
APPLY=/opt/apply-inference-from-env.sh
HIRE=/opt/bootstrap-paperclip-do-agent.sh
CREDS_FILE=/root/paperclip_admin_credentials
ENV_FILE=/opt/paperclip.env

if [ -f "$MARKER" ]; then
  exit 0
fi

# Wait for cloud-init / user-data to finish writing /etc/environment
for _ in $(seq 1 30); do
  if cloud-init status 2>/dev/null | grep -qi 'done\|disabled'; then
    break
  fi
  sleep 2
done

set -a
# shellcheck source=/dev/null
source /etc/environment 2>/dev/null || true
set +a

# Copy any newly written LLM keys into mode-600 /opt/paperclip.env and redact
# world-readable /etc/environment before apply work (apply also redacts).
ingest_and_redact_llm_keys() {
  local key val tmp
  touch "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  for key in MODEL_ACCESS_KEY OPENAI_API_KEY ANTHROPIC_API_KEY OPENROUTER_API_KEY INFERENCE_MODEL DO_INFERENCE_ROUTER; do
    val="$(printenv "$key" 2>/dev/null || true)"
    if [ -n "$val" ]; then
      tmp="$(mktemp)"
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          "${key}="*) ;;
          *) printf '%s\n' "$line" ;;
        esac
      done <"$ENV_FILE" >"$tmp"
      printf '%s=%s\n' "$key" "$val" >>"$tmp"
      mv "$tmp" "$ENV_FILE"
      chmod 600 "$ENV_FILE"
    fi
  done
  if [ -f /etc/environment ]; then
    tmp="$(mktemp)"
    grep -Ev '^(MODEL_ACCESS_KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|OPENROUTER_API_KEY)=' \
      /etc/environment >"$tmp" 2>/dev/null || : >"$tmp"
    mv "$tmp" /etc/environment
    chmod 644 /etc/environment
  fi
}
ingest_and_redact_llm_keys

sleep 5

if [ -x "$APPLY" ] && "$APPLY"; then
  if [ -f /root/.bashrc ]; then
    sed -i \
      -e '/chmod +x \/etc\/setup_wizard\.sh/d' \
      -e '/\/etc\/setup_wizard\.sh/d' \
      /root/.bashrc
  fi

  # Hire only when admin credentials exist (auto-claim already succeeded).
  if [ -x "$HIRE" ] && [ -f "$CREDS_FILE" ] \
    && grep -qE '^INITIAL_PASSWORD=.' "$CREDS_FILE" 2>/dev/null; then
    PUBLIC_URL="$(grep -E '^PAPERCLIP_PUBLIC_URL=' "$ENV_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || true)"
    "$HIRE" ${PUBLIC_URL:+"$PUBLIC_URL"} || \
      echo "WARNING: late DO agent hire failed; run sudo /opt/bootstrap-paperclip-do-agent.sh" >&2
  fi
fi

exit 0
