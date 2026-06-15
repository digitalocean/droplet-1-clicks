#!/bin/bash
# Configure Grok Build authentication from the droplet environment or
# /opt/grok-build.env.
#
# Priority:
#   1. GRADIENT_KEY  -> DigitalOcean Gradient serverless inference (default).
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

GRADIENT_KEY_VAL="$(read_value GRADIENT_KEY)"
GRADIENT_MODEL_VAL="$(read_value GRADIENT_MODEL)"
GRADIENT_ROUTER_VAL="$(read_value GRADIENT_ROUTER)"
XAI_API_KEY_VAL="$(read_value XAI_API_KEY)"

if [ -n "$GRADIENT_KEY_VAL" ]; then
    write_profiled MODEL_ACCESS_KEY "$GRADIENT_KEY_VAL"
    ensure_key_sourced_in_bashrc
    if [ -n "$GRADIENT_ROUTER_VAL" ]; then
        set_router_name "$GRADIENT_ROUTER_VAL"
        set_default_model "router"
    elif [ -n "$GRADIENT_MODEL_VAL" ]; then
        set_default_model "$GRADIENT_MODEL_VAL"
    else
        set_default_model "gpt-5-5"
    fi
    echo "DigitalOcean Gradient configured (MODEL_ACCESS_KEY)."
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
