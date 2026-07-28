#!/bin/bash
# Apply an OpenRouter API key from OPENROUTER_API_KEY.
# Returns 0 when a usable token was applied; 1 when skipped.
# Kilo OpenRouter attribution config is shipped at build time under
# /root/.config/kilo/ — this script only persists the API key.
set -euo pipefail

PROFILED=/etc/profile.d/kilocode-openrouter.sh
SETUP_MARKER=/root/.kilocode_setup_complete
BASHRC_BEGIN='# kilocode-openrouter-24-04-env BEGIN'
BASHRC_END='# kilocode-openrouter-24-04-env END'
BASHRC_RANGE_BEGIN='kilocode-openrouter-24-04-env BEGIN'
BASHRC_RANGE_END='kilocode-openrouter-24-04-env END'

env_value_usable() {
  local value="$1"
  [ -n "$value" ] || return 1
  case "$value" in
    *'${'*|PLACEHOLDER*|your_*_here) return 1 ;;
  esac
  return 0
}

remove_setup_wizard_bashrc_hook() {
  [ -f /root/.bashrc ] || return 0
  sed -i '/\/opt\/setup-kilocode-openrouter\.sh/d' /root/.bashrc
}

ensure_token_sourced() {
  touch /root/.bashrc
  if ! grep -qF "$BASHRC_RANGE_BEGIN" /root/.bashrc 2>/dev/null; then
    {
      echo ""
      echo "$BASHRC_BEGIN"
      echo "[ -f $PROFILED ] && . $PROFILED"
      echo "$BASHRC_END"
    } >> /root/.bashrc
  fi
}

write_profiled() {
  local token="$1"
  umask 077
  mkdir -p /etc/profile.d
  {
    printf 'export OPENROUTER_API_KEY=%q\n' "$token"
    printf 'export KILO_PROVIDER_TYPE=openrouter\n'
  } > "$PROFILED"
  chmod 600 "$PROFILED"
}

ensure_kilo_config_permissions() {
  # Leave shipped attribution config alone; only tighten permissions if present.
  local cfg
  for cfg in /root/.config/kilo/kilo.jsonc /root/.config/kilo/kilo.json; do
    if [ -f "$cfg" ]; then
      chmod 600 "$cfg"
    fi
  done
}

redact_token_from_system_environment() {
  local env_file=/etc/environment
  [ -f "$env_file" ] || return 0
  grep -Ev '^OPENROUTER_API_KEY=' "$env_file" >"${env_file}.tmp" 2>/dev/null || : >"${env_file}.tmp"
  mv "${env_file}.tmp" "$env_file"
  chmod 644 "$env_file"
}

OPENROUTER_TOKEN="${OPENROUTER_API_KEY-}"

if ! env_value_usable "$OPENROUTER_TOKEN"; then
  exit 1
fi

write_profiled "$OPENROUTER_TOKEN"
ensure_kilo_config_permissions
ensure_token_sourced
remove_setup_wizard_bashrc_hook
redact_token_from_system_environment
touch "$SETUP_MARKER"

echo "Testing OpenRouter API key..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${OPENROUTER_TOKEN}" \
  -H "HTTP-Referer: https://kilo.ai/" \
  -H "X-Title: Kilo Code" \
  https://openrouter.ai/api/v1/models 2>/dev/null || true)

if [ "$HTTP_STATUS" = "200" ]; then
  echo "OpenRouter API key saved for Kilo Code sessions."
else
  echo "OpenRouter API key saved for Kilo Code."
  echo "Warning: Received HTTP ${HTTP_STATUS:-000} from the OpenRouter API." >&2
fi

exit 0
