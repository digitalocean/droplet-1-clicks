#!/bin/bash
# Apply a DigitalOcean model access key from DIGITALOCEAN_ACCESS_TOKEN.
# Returns 0 when a usable token was applied; 1 when skipped.
set -euo pipefail

PROFILED=/etc/profile.d/kilocode-digitalocean.sh
SETUP_MARKER=/root/.kilocode_setup_complete
BASHRC_BEGIN='# kilocode-24-04-digitalocean-env BEGIN'
BASHRC_END='# kilocode-24-04-digitalocean-env END'
BASHRC_RANGE_BEGIN='kilocode-24-04-digitalocean-env BEGIN'
BASHRC_RANGE_END='kilocode-24-04-digitalocean-env END'

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
  sed -i '/\/opt\/setup-kilocode\.sh/d' /root/.bashrc
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
    printf 'export DIGITALOCEAN_ACCESS_TOKEN=%q\n' "$token"
    printf 'export KILO_PROVIDER_TYPE=digitalocean\n'
  } > "$PROFILED"
  chmod 600 "$PROFILED"
}

redact_token_from_system_environment() {
  local env_file=/etc/environment
  [ -f "$env_file" ] || return 0
  grep -Ev '^DIGITALOCEAN_ACCESS_TOKEN=' "$env_file" >"${env_file}.tmp" 2>/dev/null || : >"${env_file}.tmp"
  mv "${env_file}.tmp" "$env_file"
  chmod 644 "$env_file"
}

DIGITALOCEAN_TOKEN="${DIGITALOCEAN_ACCESS_TOKEN-}"

if ! env_value_usable "$DIGITALOCEAN_TOKEN"; then
  exit 1
fi

write_profiled "$DIGITALOCEAN_TOKEN"
ensure_token_sourced
remove_setup_wizard_bashrc_hook
redact_token_from_system_environment
touch "$SETUP_MARKER"

echo "Testing DigitalOcean model access key..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
  -H "Content-Type: application/json" \
  https://inference.do-ai.run/v1/models 2>/dev/null || true)

if [ "$HTTP_STATUS" = "200" ]; then
  echo "DigitalOcean model access key saved for Kilo Code sessions."
else
  echo "DigitalOcean model access key saved for Kilo Code."
  echo "Warning: Received HTTP ${HTTP_STATUS:-000} from the inference API." >&2
fi

exit 0
