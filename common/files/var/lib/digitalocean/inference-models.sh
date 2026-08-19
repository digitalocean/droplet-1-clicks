#!/bin/bash
# Shared DigitalOcean Serverless Inference catalog helpers for Droplet 1-Clicks.
#
# Packer copies this file to /var/lib/digitalocean/inference-models.sh on every
# image that provisions common/files/var/. Other 1-Clicks should source that
# path from their setup wizards instead of hardcoding model IDs:
#
#   . /var/lib/digitalocean/inference-models.sh
#   json="$(fetch_inference_models_json "$MODEL_ACCESS_KEY")" || return 1
#   chat_ids="$(printf '%s' "$json" | parse_inference_model_ids | filter_chat_inference_models)"
#
# Live catalog: GET https://inference.do-ai.run/v1/models
# Authenticate with a model access key (Bearer). Response shape:
# https://docs.digitalocean.com/products/inference/how-to/retrieve-available-models/
#
# Source this file; do not execute it.

INFERENCE_MODELS_URL="${INFERENCE_MODELS_URL:-https://inference.do-ai.run/v1/models}"

parse_inference_model_ids() {
    jq -r '.data[]?.id // empty' | sed '/^$/d' | sort -u
}

inference_model_is_chat() {
    local id="$1"
    case "$id" in
        fal-ai/*|*embed*|*rerank*|*tts*|*whisper*|*image*|*video*|*audio*|*speech*|*flux*|*sdxl*)
            return 1
            ;;
    esac
    return 0
}

filter_chat_inference_models() {
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        if inference_model_is_chat "$id"; then
            printf '%s\n' "$id"
        fi
    done
}

pick_default_inference_model() {
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        printf '%s' "$id"
        return 0
    done
    return 1
}

resolve_inference_model_choice() {
    local selection="${1-}"
    local -a models=()
    local line

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        models+=("$line")
    done

    if [ "${#models[@]}" -eq 0 ]; then
        echo "No models available to select." >&2
        return 1
    fi

    if [ -z "$selection" ]; then
        printf '%s' "${models[0]}"
        return 0
    fi

    local m
    for m in "${models[@]}"; do
        if [ "$selection" = "$m" ]; then
            printf '%s' "$m"
            return 0
        fi
    done

    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        echo "Selection must be a number between 1 and ${#models[@]}." >&2
        return 1
    fi

    if [ "$selection" -lt 1 ] || [ "$selection" -gt "${#models[@]}" ]; then
        echo "Selection must be a number between 1 and ${#models[@]}." >&2
        return 1
    fi

    printf '%s' "${models[$((selection - 1))]}"
}

fetch_inference_models_json() {
    local key="$1"
    local tmp status

    tmp="$(mktemp)"
    status="$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 20 \
        -H "Authorization: Bearer ${key}" \
        -H "Content-Type: application/json" \
        "$INFERENCE_MODELS_URL" 2>/dev/null)" || status="000"
    INFERENCE_MODELS_HTTP_STATUS="$status"

    if [ "$status" != "200" ]; then
        rm -f "$tmp"
        return 1
    fi

    cat "$tmp"
    rm -f "$tmp"
    return 0
}

# Prints chat-capable model ids, one per line. Returns 0 on success.
list_chat_inference_models() {
    local key="$1"
    local json

    json="$(fetch_inference_models_json "$key")" || return 1
    printf '%s' "$json" | parse_inference_model_ids | filter_chat_inference_models
}
