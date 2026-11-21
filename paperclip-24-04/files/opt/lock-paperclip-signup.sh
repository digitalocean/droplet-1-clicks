#!/bin/bash
# Lock open email signup (invite acceptance / sign-in still work once an admin exists).
# Used after first-admin claim, on first-boot health failure, and by the
# claim-failure watcher once an admin appears.
set -euo pipefail

ENV_FILE="${PAPERCLIP_ENV_FILE:-/opt/paperclip.env}"
INSTANCE_ENV="${PAPERCLIP_INSTANCE_ENV:-/home/paperclip/.paperclip/instances/default/.env}"
CONFIG_PATH="${PAPERCLIP_CONFIG_PATH:-/home/paperclip/.paperclip/instances/default/config.json}"

write_env_kv() {
  local file="$1" key="$2" val="$3" tmp
  touch "$file"
  tmp="$(mktemp)"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${key}="*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$file" >"$tmp"
  printf '%s=%s\n' "$key" "$val" >>"$tmp"
  mv "$tmp" "$file"
  chmod 600 "$file"
}

write_env_kv "$ENV_FILE" PAPERCLIP_AUTH_DISABLE_SIGN_UP true

if [ -f "$INSTANCE_ENV" ]; then
  write_env_kv "$INSTANCE_ENV" PAPERCLIP_AUTH_DISABLE_SIGN_UP true
  if id paperclip >/dev/null 2>&1; then
    chown paperclip:paperclip "$INSTANCE_ENV"
  fi
fi

if [ -f "$CONFIG_PATH" ]; then
  python3 - <<'PY'
import json
path = "/home/paperclip/.paperclip/instances/default/config.json"
with open(path, encoding="utf-8") as handle:
    cfg = json.load(handle)
cfg.setdefault("auth", {})["disableSignUp"] = True
with open(path, "w", encoding="utf-8") as handle:
    json.dump(cfg, handle, indent=2)
    handle.write("\n")
PY
  if id paperclip >/dev/null 2>&1; then
    chown paperclip:paperclip "$CONFIG_PATH"
  fi
fi

if systemctl is-active --quiet paperclip 2>/dev/null; then
  systemctl restart paperclip || true
fi

echo "Paperclip open signup locked (PAPERCLIP_AUTH_DISABLE_SIGN_UP=true)."
