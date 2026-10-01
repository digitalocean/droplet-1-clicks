#!/bin/bash
# Shared helpers for 001_onboot and /etc/setup_wizard.sh. Source, don't run.

ENV_FILE=/opt/qm/.env

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
