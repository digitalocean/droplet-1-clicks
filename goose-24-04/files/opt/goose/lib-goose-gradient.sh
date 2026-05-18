#!/bin/bash
# Shared helpers for DigitalOcean Gradient + Goose (sourced by other scripts; not executed).
# shellcheck shell=bash

GOOSE_CFG=/root/.config/goose/config.yaml
GOOSE_SECRETS=/root/.config/goose/secrets.yaml
PROFILED=/etc/profile.d/goose-gradient.sh
BASHRC_BEGIN='# goose-24-04-gradient-env BEGIN'
BASHRC_END='# goose-24-04-gradient-env END'
# sed range match (unique substring; avoids leading # in sed address)
BASHRC_RANGE_BEGIN='goose-24-04-gradient-env BEGIN'
BASHRC_RANGE_END='goose-24-04-gradient-env END'

goose_gradient_yaml_escape_double() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

goose_gradient_ensure_bashrc_hook() {
    touch /root/.bashrc
    if ! grep -qF "$BASHRC_RANGE_BEGIN" /root/.bashrc 2>/dev/null; then
        {
            echo ""
            echo "$BASHRC_BEGIN"
            echo "[ -f $PROFILED ] && . $PROFILED"
            echo "$BASHRC_END"
        } >>/root/.bashrc
    fi
}

goose_gradient_remove_bashrc_hook() {
    if [ -f /root/.bashrc ]; then
        sed -i "/${BASHRC_RANGE_BEGIN}/,/${BASHRC_RANGE_END}/d" /root/.bashrc
    fi
}

goose_gradient_upsert_config_kv() {
    local key="$1" val="$2"
    install -d -m 700 /root/.config/goose
    touch "$GOOSE_CFG"
    if grep -q "^${key}:" "$GOOSE_CFG" 2>/dev/null; then
        sed -i "s|^${key}:.*|${key}: ${val}|" "$GOOSE_CFG"
    else
        printf '%s: %s\n' "$key" "$val" >>"$GOOSE_CFG"
    fi
    chmod 600 "$GOOSE_CFG"
}

goose_gradient_write_profiled() {
    local key="$1"
    umask 077
    printf 'export DO_GRADIENT_API_KEY=%q\n' "$key" >"$PROFILED"
    chmod 600 "$PROFILED"
}

goose_gradient_write_secrets_yaml() {
    local key="$1"
    local line
    line="DO_GRADIENT_API_KEY: \"$(goose_gradient_yaml_escape_double "$key")\""
    install -d -m 700 /root/.config/goose
    if [ -f "$GOOSE_SECRETS" ]; then
        grep -v '^DO_GRADIENT_API_KEY:' "$GOOSE_SECRETS" >"${GOOSE_SECRETS}.tmp" 2>/dev/null || true
        mv -f "${GOOSE_SECRETS}.tmp" "$GOOSE_SECRETS"
    fi
    printf '%s\n' "$line" >>"$GOOSE_SECRETS"
    chmod 600 "$GOOSE_SECRETS"
}

goose_gradient_remove_secret_line() {
    if [ -f "$GOOSE_SECRETS" ]; then
        grep -v '^DO_GRADIENT_API_KEY:' "$GOOSE_SECRETS" >"${GOOSE_SECRETS}.tmp" 2>/dev/null || true
        mv -f "${GOOSE_SECRETS}.tmp" "$GOOSE_SECRETS"
        chmod 600 "$GOOSE_SECRETS" 2>/dev/null || true
    fi
}

# Copy bundled declarative JSON from /opt (e.g. after updating files on a long-lived Droplet).
goose_gradient_sync_declarative_json() {
    local src=/opt/goose/custom_providers/digitalocean_gradient.json
    local dst_dir=/root/.config/goose/custom_providers
    local dst="$dst_dir/digitalocean_gradient.json"
    if [ -f "$src" ]; then
        mkdir -p "$dst_dir"
        cp -f "$src" "$dst"
        chmod 644 "$dst"
    fi
}

# Interim builds used GOOSE_PROVIDER: kimi while the declarative name was a workaround; canonical id is digitalocean_gradient.
goose_gradient_migrate_legacy_provider() {
    [ -f "$GOOSE_CFG" ] || return 0
    if grep -E '^GOOSE_PROVIDER:[[:space:]]+kimi[[:space:]]*$' "$GOOSE_CFG" 2>/dev/null; then
        goose_gradient_upsert_config_kv GOOSE_PROVIDER digitalocean_gradient
        echo "Updated GOOSE_PROVIDER from kimi to digitalocean_gradient (matches declarative JSON file)." >&2
    fi
}

# Default Gradient model when GOOSE_MODEL is unset (rotating the API key does not overwrite an existing GOOSE_MODEL).
goose_gradient_ensure_default_model_minimax() {
    if [ -f "$GOOSE_CFG" ] && grep -q '^GOOSE_MODEL:' "$GOOSE_CFG" 2>/dev/null; then
        return 0
    fi
    goose_gradient_upsert_config_kv GOOSE_MODEL minimax-m2.5
}

# Apply key to profile.d, bashrc, Goose secrets.yaml, and default provider in config.yaml.
goose_gradient_apply_full() {
    local grad_key="$1"
    goose_gradient_sync_declarative_json
    goose_gradient_migrate_legacy_provider
    goose_gradient_write_profiled "$grad_key"
    goose_gradient_ensure_bashrc_hook
    goose_gradient_write_secrets_yaml "$grad_key"
    # File-backed secrets work reliably on headless images (no secret service / non-login SSH).
    goose_gradient_upsert_config_kv GOOSE_DISABLE_KEYRING '"true"'
    goose_gradient_upsert_config_kv GOOSE_PROVIDER digitalocean_gradient
    goose_gradient_ensure_default_model_minimax
    # shellcheck source=/dev/null
    . "$PROFILED"
}

# Remove Gradient key from shell env files and Goose secrets (not GOOSE_PROVIDER in config.yaml).
goose_gradient_remove_env_files() {
    rm -f "$PROFILED"
    goose_gradient_remove_bashrc_hook
    goose_gradient_remove_secret_line
}
