#!/bin/bash
# Publish the onboarding DigitalOcean Inference tile into Paperclip's managed UI.
#
# The tile is visible only when inference is already configured. The public JSON
# carries the OpenCode model id (digitalocean/<id>) and never the access key.
#
#   /opt/install-paperclip-inference-ui.sh --from-env
#
# PAPERCLIP_UI_DIST, PAPERCLIP_ENV_FILE, and PAPERCLIP_SETUP_MARKER override
# the droplet paths for tests.
set -euo pipefail

ENV_FILE="${PAPERCLIP_ENV_FILE:-/opt/paperclip.env}"
SETUP_MARKER="${PAPERCLIP_SETUP_MARKER:-/opt/paperclip/.provider-configured}"
SOURCE_JS="${PAPERCLIP_INFERENCE_UI_JS:-/opt/paperclip/digitalocean-inference-onboarding.js}"
SCRIPT_NAME="digitalocean-inference.js"
JSON_NAME="digitalocean-inference.json"
SCRIPT_TAG='<script src="/digitalocean-inference.js?v=5" defer></script>'

read_env_value() {
  local key="$1" line value
  [ -f "$ENV_FILE" ] || return 0
  line="$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1 || true)"
  value="${line#*=}"
  case "$value" in
    \"*\")
      value="${value#\"}"
      value="${value%\"}"
      ;;
  esac
  printf '%s' "$value"
}

discover_ui_dists() {
  if [ -n "${PAPERCLIP_UI_DIST:-}" ]; then
    printf '%s\n' "$PAPERCLIP_UI_DIST"
    return 0
  fi
  local home
  home="$(getent passwd paperclip 2>/dev/null | cut -d: -f6 || true)"
  [ -n "$home" ] || home=/home/paperclip
  [ -d "$home" ] || return 0
  find "$home" -type f -path '*/ui-dist/index.html' 2>/dev/null | while IFS= read -r index; do
    dirname "$index"
  done
}

publish_one() {
  local ui_dist="$1" enabled="$2" model="$3" index script_path json_path
  if [ ! -d "$ui_dist" ]; then
    echo "Paperclip ui-dist is not a directory: ${ui_dist}" >&2
    return 1
  fi
  index="${ui_dist}/index.html"
  if [ ! -f "$index" ]; then
    echo "Paperclip index.html missing: ${index}" >&2
    return 1
  fi
  if [ ! -f "$SOURCE_JS" ]; then
    echo "Paperclip inference UI source missing: ${SOURCE_JS}" >&2
    return 1
  fi

  script_path="${ui_dist}/${SCRIPT_NAME}"
  json_path="${ui_dist}/${JSON_NAME}"
  cp "$SOURCE_JS" "$script_path"
  chmod 644 "$script_path"
  if [ ! -s "$script_path" ]; then
    echo "Failed to copy DigitalOcean Inference script into ${script_path}" >&2
    return 1
  fi
  python3 - "$json_path" "$enabled" "$model" <<'PY'
import json
import sys
path, enabled, model = sys.argv[1], sys.argv[2], sys.argv[3]
doc = {
    "enabled": enabled == "true",
    "label": "DigitalOcean",
    "tag": "Inference",
    "model": model if enabled == "true" else "",
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(doc, handle, separators=(",", ":"))
    handle.write("\n")
PY
  if [ "$?" -ne 0 ]; then
    return 1
  fi
  chmod 644 "$json_path"
  if [ ! -s "$json_path" ]; then
    echo "Failed to write DigitalOcean Inference config into ${json_path}" >&2
    return 1
  fi

  python3 - "$index" "$SCRIPT_TAG" <<'PY'
import pathlib, re, sys
path, tag = sys.argv[1], sys.argv[2]
file = pathlib.Path(path)
text = re.sub(r'\s*<script src="/digitalocean-inference\.js[^"]*" defer></script>', "", file.read_text(encoding="utf-8"))
if "</body>" not in text:
    raise SystemExit("Paperclip index.html has no </body>")
file.write_text(text.replace("</body>", tag + "\n</body>", 1), encoding="utf-8")
PY
  if [ "$?" -ne 0 ]; then
    return 1
  fi
  if ! grep -F "$SCRIPT_TAG" "$index" >/dev/null; then
    echo "DigitalOcean Inference script tag was not written into ${index}" >&2
    return 1
  fi

  if id paperclip >/dev/null 2>&1; then
    chown paperclip:paperclip "$script_path" "$json_path" "$index" || true
  fi
}

main() {
  local enabled="false" model="" inference providers
  if [ "${1:-}" != "--from-env" ]; then
    echo "usage: $0 --from-env" >&2
    exit 2
  fi

  inference="$(read_env_value INFERENCE_MODEL)"
  providers="$(read_env_value PAPERCLIP_OPENCODE_PROVIDERS)"
  if [ -f "$SETUP_MARKER" ] && [ -n "$providers" ] && printf '%s' "$inference" | grep -Eq '^[A-Za-z0-9_.:/+-]+$'; then
    enabled="true"
    case "$inference" in
      digitalocean/*) model="$inference" ;;
      *) model="digitalocean/${inference}" ;;
    esac
  fi

  if [ ! -f "$SOURCE_JS" ]; then
    echo "Paperclip inference UI source missing: ${SOURCE_JS}" >&2
    exit 1
  fi

  local found=0 dir
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    found=1
    if ! publish_one "$dir" "$enabled" "$model"; then
      exit 1
    fi
  done < <(discover_ui_dists)

  if [ "$found" -eq 0 ]; then
    echo "Paperclip ui-dist was not found; DigitalOcean Inference tile was not published." >&2
    exit 1
  fi
}

main "$@"
