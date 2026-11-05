#!/bin/bash
# Apply DigitalOcean Serverless Inference to the DSH Superagent profile.
#
# Reads MODEL_ACCESS_KEY, optional INFERENCE_MODEL, and optional
# DO_INFERENCE_ROUTER from the environment, /etc/environment, or
# /opt/dsh-superagent/dsh-superagent-inference.env.
#
# The key is stored for the superagent user and removed from /etc/environment.
# The profile patch names the gateway and its models, never the key. Eval and
# executor selection is recorded for push-inference-model.sh, which runs after
# the service is up.
#
# Returns 0 when a key was applied, 1 when skipped because no usable key is set.
set -euo pipefail

ENV_FILE=/opt/dsh-superagent/dsh-superagent-inference.env
APP_USER=superagent
APP_HOME=/home/superagent
APP_ENV=$APP_HOME/.config/dsh-superagent/env
PATCH=$APP_HOME/.dsh/profiles/superagent/cordis.patch.yml
ROLE_MODEL=/var/lib/digitalocean/dsh-superagent-role-model.json
MARKER=/var/lib/digitalocean/dsh-superagent-inference-configured
INFERENCE_MODELS_LIB=${INFERENCE_MODELS_LIB:-/var/lib/digitalocean/inference-models.sh}
INFERENCE_BASE_URL=https://inference.do-ai.run/v1
PROVIDER=digitalocean

env_value_usable() {
    local v="$1"
    [ -n "$v" ] || return 1
    case "$v" in
        *'${'*|PLACEHOLDER*|your_*_here|*$'\n'*) return 1 ;;
    esac
    return 0
}

read_file_kv() {
    local file="$1" key="$2" line val
    [ -f "$file" ] || return 1
    line=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1) || return 1
    val="${line#${key}=}"
    val="${val#\"}"; val="${val%\"}"
    val="${val#\'}"; val="${val%\'}"
    printf '%s' "$val"
}

read_config_value() {
    local key="$1" val
    val="${!key-}"
    if env_value_usable "$val"; then
        printf '%s' "$val"
        return 0
    fi
    val=$(read_file_kv /etc/environment "$key" || true)
    if env_value_usable "$val"; then
        printf '%s' "$val"
        return 0
    fi
    read_file_kv "$ENV_FILE" "$key"
}

model_id_ok() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$ ]]
}

# Primary model first, then the rest of the catalog, without duplicates.
ordered_inference_model_ids() {
    local primary="$1"
    local ids="$2"
    printf '%s\n%s\n' "$primary" "$ids" | awk 'NF && !seen[$0]++'
}

# Profile patch for the running Droplet. Model ids are validated before this runs.
render_profile_patch() {
    local models_file="$1" id
    cat <<'EOF'
# DSH Superagent machine configuration.
# The panel stays on loopback. DigitalOcean Inference is an OpenAI-compatible
# gateway; the model access key is not stored in this file.
- id: webserver
  config:
    host: 127.0.0.1
    port: 3082
- id: dsh-superagent
  config:
    stateDir: /home/superagent/.dsh/state/superagent
- insert:
    - id: llm-pi-ai
      name: '@deepseek-ai/dsh-llm-pi-ai'
      config:
        providers:
          digitalocean:
            displayName: DigitalOcean Inference
            apiKeyEnv: MODEL_ACCESS_KEY
            api: openai-completions
            baseURL: https://inference.do-ai.run/v1
            models:
EOF
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        printf '              - id: %s\n                name: %s\n' "$id" "$id"
    done < "$models_file"
}

write_owned_file() {
    local user="$1" destination="$2" mode="$3"
    runuser -u "$user" -- bash -c '
        set -euo pipefail
        destination="$1"
        mode="$2"
        directory="$(dirname -- "$destination")"
        mkdir -p -- "$directory"
        temporary="$(mktemp "${directory}/.dsh-superagent.XXXXXX")"
        trap "rm -f -- \"$temporary\"" EXIT
        cat >"$temporary"
        chmod "$mode" "$temporary"
        mv -f -- "$temporary" "$destination"
    ' bash "$destination" "$mode"
}

write_app_env_kv() {
    local key="$1" val="$2"
    runuser -u "$APP_USER" -- env KEY="$key" VAL="$val" FILE="$APP_ENV" bash -c '
        set -euo pipefail
        mkdir -p -- "$(dirname -- "$FILE")"
        chmod 700 "$(dirname -- "$FILE")"
        touch -- "$FILE"
        temporary="$(mktemp "$(dirname -- "$FILE")/.env.XXXXXX")"
        trap "rm -f -- \"$temporary\"" EXIT
        grep -v "^${KEY}=" "$FILE" >"$temporary" 2>/dev/null || : >"$temporary"
        printf "%s=%q\n" "$KEY" "$VAL" >>"$temporary"
        chmod 600 "$temporary"
        mv -f -- "$temporary" "$FILE"
    '
}

strip_inference_keys() {
    # With set -u, one local line expands ${env_file} before that assignment exists.
    local env_file="$1"
    local mode="$2"
    local tmp="${env_file}.tmp"
    [ -f "$env_file" ] || return 0
    grep -Ev '^(MODEL_ACCESS_KEY|INFERENCE_MODEL|DO_INFERENCE_ROUTER)=' "$env_file" >"$tmp" 2>/dev/null || : >"$tmp"
    mv "$tmp" "$env_file"
    chmod "$mode" "$env_file"
}

apply_inference() {
    local key model router chat_ids primary model_ids model_file id
    key=$(read_config_value MODEL_ACCESS_KEY || true)
    model=$(read_config_value INFERENCE_MODEL || true)
    router=$(read_config_value DO_INFERENCE_ROUTER || true)
    if ! env_value_usable "$key"; then
        return 1
    fi

    chat_ids=""
    if [ -f "$INFERENCE_MODELS_LIB" ]; then
        # shellcheck source=/var/lib/digitalocean/inference-models.sh
        . "$INFERENCE_MODELS_LIB"
        chat_ids="$(list_chat_inference_models "$key" || true)"
    fi

    if env_value_usable "$router"; then
        router="${router#openai/}"
        router="${router#digitalocean/}"
        router="${router#router:}"
        primary="router:${router}"
    else
        router=""
        if ! env_value_usable "$model"; then
            if [ -z "$chat_ids" ]; then
                echo "Could not list Serverless Inference models and no INFERENCE_MODEL was set." >&2
                return 1
            fi
            model="$(printf '%s\n' "$chat_ids" | pick_default_inference_model)"
        fi
        model="${model#openai/}"
        model="${model#digitalocean/}"
        primary="$model"
    fi
    if ! model_id_ok "$primary"; then
        echo "Unsupported model id: ${primary}" >&2
        return 1
    fi

    model_ids="$(ordered_inference_model_ids "$primary" "$chat_ids")"
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        if ! model_id_ok "$id"; then
            echo "Skipping unsupported model id: ${id}" >&2
            model_ids="$(printf '%s\n' "$model_ids" | grep -Fxv "$id" || true)"
        fi
    done <<< "$model_ids"
    if [ -z "$model_ids" ]; then
        echo "No usable Serverless Inference model ids." >&2
        return 1
    fi

    touch "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    local tmp="${ENV_FILE}.tmp"
    grep -Ev '^(MODEL_ACCESS_KEY|INFERENCE_MODEL|DO_INFERENCE_ROUTER)=' "$ENV_FILE" >"$tmp" 2>/dev/null || : >"$tmp"
    {
        printf 'MODEL_ACCESS_KEY=%q\n' "$key"
        printf 'INFERENCE_MODEL=%q\n' "${primary#router:}"
        printf 'DO_INFERENCE_ROUTER=%q\n' "$router"
    } >>"$tmp"
    mv "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    strip_inference_keys /etc/environment 644

    write_app_env_kv MODEL_ACCESS_KEY "$key"

    model_file="$(mktemp)"
    printf '%s\n' "$model_ids" >"$model_file"
    render_profile_patch "$model_file" | write_owned_file "$APP_USER" "$PATCH" 644
    rm -f "$model_file"

    install -d -m 755 -o root -g root "$(dirname "$ROLE_MODEL")"
    (umask 077
        jq -n --arg provider "$PROVIDER" --arg model "$primary" \
            '{provider: $provider, model: $model}' >"$ROLE_MODEL")
    chmod 600 "$ROLE_MODEL"
    install -m 600 -o root -g root /dev/null "$MARKER"

    echo "DigitalOcean Serverless Inference configured: ${PROVIDER}/${primary}"
    echo "Restart DSH Superagent, then run /opt/dsh-superagent/push-inference-model.sh."
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    apply_inference
fi
