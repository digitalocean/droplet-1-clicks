#!/bin/bash
# Configure Grok Build authentication from the droplet environment or
# /opt/grok-build.env.
#
# Priority:
#   1. MODEL_ACCESS_KEY -> DigitalOcean Serverless Inference (default).
#                       Sets the default model / router in config.toml.
#   2. XAI_API_KEY   -> xAI native model (the grok-build entry).
#
# The key itself is NEVER written into config.toml. It is stored once in
# /etc/profile.d/grok-build-key.sh (mode 600) and exported as the env var that
# the config.toml model entries reference via env_key (MODEL_ACCESS_KEY /
# XAI_API_KEY). To make that key available in EVERY shell -- login and non-login
# (tmux, IDE remote terminals, nested bash) -- we also source it from
# /root/.bashrc. The first-login flow (001_onboot + this script) is arranged so
# the key is loaded into the live shell immediately after the setup wizard runs.
#
# Returns 0 when a key was applied; 1 when nothing was configured.
set -euo pipefail

ENV_FILE="/opt/grok-build.env"
KEY_PROFILED="/etc/profile.d/grok-build-key.sh"
CONFIG_FILE="/root/.grok/config.toml"
INFERENCE_MODELS_LIB="/var/lib/digitalocean/inference-models.sh"
PREFERRED_INFERENCE_MODEL="openai-gpt-5.5"
BASHRC="/root/.bashrc"
BASHRC_BEGIN="# grok-build-24-04-key-env BEGIN"
BASHRC_END="# grok-build-24-04-key-env END"

read_file_kv() {
    local key="$1" line val
    line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
    val="${line#"${key}"=}"
    val="${val#\"}"; val="${val%\"}"
    val="${val#\'}"; val="${val%\'}"
    printf '%s' "$val"
}

read_value() {
    local key="$1" env_val="${!1:-}"
    if [ -n "$env_val" ]; then
        printf '%s' "$env_val"
        return 0
    fi
    read_file_kv "$key" || true
}

set_default_model() {
    # Replace the value of `default = "..."` under [models] in config.toml.
    local alias="$1"
    [ -f "$CONFIG_FILE" ] || return 0
    sed -i "s|^\([[:space:]]*default[[:space:]]*=[[:space:]]*\).*|\1\"${alias}\"|" "$CONFIG_FILE"
}

set_router_name() {
    # Point the [model.router] entry at router:<name>.
    local name="$1"
    [ -f "$CONFIG_FILE" ] || return 0
    sed -i "s|^\([[:space:]]*model[[:space:]]*=[[:space:]]*\)\"router:[^\"]*\"|\1\"router:${name}\"|" "$CONFIG_FILE"
}

write_profiled() {
    # write_profiled VAR VALUE  (clears the file and writes a single export)
    umask 077
    mkdir -p /etc/profile.d
    printf 'export %s=%q\n' "$1" "$2" > "$KEY_PROFILED"
    chmod 600 "$KEY_PROFILED"
}

ensure_key_sourced_in_bashrc() {
    # Source the key file from .bashrc so the key is present in non-login
    # interactive shells too (tmux, IDE remote terminals, nested bash), not just
    # login shells. Idempotent (guarded by the BEGIN marker).
    touch "$BASHRC"
    if ! grep -qF "$BASHRC_BEGIN" "$BASHRC" 2>/dev/null; then
        {
            echo ""
            echo "$BASHRC_BEGIN"
            echo "[ -f $KEY_PROFILED ] && . $KEY_PROFILED"
            echo "$BASHRC_END"
        } >> "$BASHRC"
    fi
}

# Refresh [model.*] entries between markers from the live catalog. Prints the
# alias that should be set as [models].default for the chosen API id / alias.
sync_inference_catalog() {
    local chosen="$1"
    local ids_file="$2"

    python3 - "$CONFIG_FILE" "$chosen" "$ids_file" "$PREFERRED_INFERENCE_MODEL" <<'PY'
import re
import sys

config_path, chosen, ids_path, preferred = sys.argv[1:5]
begin = "# BEGIN digitalocean-inference-models"
end = "# END digitalocean-inference-models"
reserved = {"grok-build", "router"}

def sanitize(model_id: str) -> str:
    alias = model_id.replace(".", "-")
    alias = re.sub(r"[^A-Za-z0-9_-]", "-", alias)
    alias = re.sub(r"-{2,}", "-", alias).strip("-")
    return alias or "model"

def parse_blocks(text: str):
    mapping = {}
    current = None
    fields = {}
    for line in text.splitlines():
        header = re.match(r"^\[model\.([^\]]+)\]\s*$", line)
        if header:
            if current and current not in reserved:
                mapping[current] = fields
            current = header.group(1)
            fields = {}
            continue
        if current and re.match(r"^\[", line):
            if current not in reserved:
                mapping[current] = fields
            current = None
            fields = {}
            continue
        if current is None:
            continue
        match = re.match(r'^([A-Za-z0-9_]+)\s*=\s*"(.*)"\s*$', line)
        if match:
            fields[match.group(1)] = match.group(2)
    if current and current not in reserved:
        mapping[current] = fields
    return mapping

with open(config_path, encoding="utf-8") as fh:
    text = fh.read()

live_ids = []
with open(ids_path, encoding="utf-8") as fh:
    for line in fh:
        model_id = line.strip()
        if model_id:
            live_ids.append(model_id)

existing = parse_blocks(text)
id_by_alias = {alias: fields.get("model", "") for alias, fields in existing.items()}
alias_by_id = {}
for alias, model_id in id_by_alias.items():
    if model_id and model_id not in alias_by_id:
        alias_by_id[model_id] = alias

chosen_alias = "gpt-5-5"
chosen_id = chosen.strip()
if not chosen_id:
    if preferred in live_ids:
        chosen_id = preferred
    elif live_ids:
        chosen_id = live_ids[0]
    elif "gpt-5-5" in id_by_alias:
        chosen_id = id_by_alias["gpt-5-5"] or preferred
    else:
        chosen_id = preferred
elif chosen_id in id_by_alias:
    chosen_id = id_by_alias[chosen_id] or chosen_id

ordered = []
seen = set()
for model_id in [chosen_id] + live_ids:
    if model_id and model_id not in seen:
        ordered.append(model_id)
        seen.add(model_id)

used_aliases = set()
entries = []
for model_id in ordered:
    alias = alias_by_id.get(model_id) or sanitize(model_id)
    base = alias
    n = 2
    while alias in used_aliases:
        alias = f"{base}-{n}"
        n += 1
    used_aliases.add(alias)
    prev = existing.get(alias, {})
    name = prev.get("name") or f"{model_id} (DigitalOcean Inference)"
    entries.append((alias, model_id, name))
    if model_id == chosen_id:
        chosen_alias = alias

if not entries:
    print("gpt-5-5", end="")
    raise SystemExit(0)

blocks = [
    "# === DigitalOcean Serverless Inference models ===",
    "# Refreshed from GET https://inference.do-ai.run/v1/models when a key is applied.",
    "",
]
for alias, model_id, name in entries:
    blocks.extend(
        [
            f"[model.{alias}]",
            f'model = "{model_id}"',
            'base_url = "https://inference.do-ai.run/v1"',
            f'name = "{name}"',
            'env_key = "MODEL_ACCESS_KEY"',
            "",
        ]
    )
new_region = "\n".join(blocks).rstrip() + "\n"

if begin in text and end in text:
    pre, rest = text.split(begin, 1)
    _, post = rest.split(end, 1)
    text = f"{pre}{begin}\n{new_region}{end}{post}"
    with open(config_path, "w", encoding="utf-8") as fh:
        fh.write(text)

print(chosen_alias, end="")
PY
}

choose_inference_default() {
    local requested="$1"
    local chat_ids="$2"
    local tmp alias

    tmp="$(mktemp)"
    if [ -n "$chat_ids" ]; then
        printf '%s\n' "$chat_ids" >"$tmp"
    else
        : >"$tmp"
    fi

    if alias="$(sync_inference_catalog "$requested" "$tmp")"; then
        rm -f "$tmp"
        if [ -n "$alias" ]; then
            printf '%s' "$alias"
            return 0
        fi
    else
        rm -f "$tmp"
    fi

    if [ -n "$requested" ]; then
        printf '%s' "$requested"
        return 0
    fi
    printf '%s' "gpt-5-5"
}

MODEL_ACCESS_KEY_VAL="$(read_value MODEL_ACCESS_KEY)"
DO_INFERENCE_MODEL_VAL="$(read_value DO_INFERENCE_MODEL)"
DO_INFERENCE_ROUTER_VAL="$(read_value DO_INFERENCE_ROUTER)"
XAI_API_KEY_VAL="$(read_value XAI_API_KEY)"

if [ -n "$MODEL_ACCESS_KEY_VAL" ]; then
    write_profiled MODEL_ACCESS_KEY "$MODEL_ACCESS_KEY_VAL"
    ensure_key_sourced_in_bashrc

    CHAT_IDS=""
    if [ -f "$INFERENCE_MODELS_LIB" ]; then
        # shellcheck source=/var/lib/digitalocean/inference-models.sh
        . "$INFERENCE_MODELS_LIB"
        CHAT_IDS="$(list_chat_inference_models "$MODEL_ACCESS_KEY_VAL" || true)"
        if [ -z "$CHAT_IDS" ]; then
            json="$(fetch_inference_models_json "$MODEL_ACCESS_KEY_VAL" || true)"
            if [ -n "$json" ]; then
                CHAT_IDS="$(printf '%s' "$json" | parse_inference_model_ids || true)"
            fi
        fi
    fi

    if [ -n "$DO_INFERENCE_ROUTER_VAL" ]; then
        choose_inference_default "$DO_INFERENCE_MODEL_VAL" "$CHAT_IDS" >/dev/null || true
        set_router_name "$DO_INFERENCE_ROUTER_VAL"
        set_default_model "router"
        echo "DigitalOcean Serverless Inference configured (MODEL_ACCESS_KEY, router)."
        exit 0
    fi

    DEFAULT_ALIAS="$(choose_inference_default "$DO_INFERENCE_MODEL_VAL" "$CHAT_IDS")"
    set_default_model "$DEFAULT_ALIAS"
    echo "DigitalOcean Serverless Inference configured (MODEL_ACCESS_KEY): ${DEFAULT_ALIAS}"
    exit 0
fi

if [ -n "$XAI_API_KEY_VAL" ]; then
    write_profiled XAI_API_KEY "$XAI_API_KEY_VAL"
    ensure_key_sourced_in_bashrc
    set_default_model "grok-build"
    echo "xAI API key configured (XAI_API_KEY)."
    exit 0
fi

exit 1
