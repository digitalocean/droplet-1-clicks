#!/bin/bash
# Point DSH Superagent's eval and executor at the DigitalOcean Inference model
# recorded by apply-inference-from-env.sh. Other settings in those blocks are kept.
set -euo pipefail

ROLE_MODEL=/var/lib/digitalocean/dsh-superagent-role-model.json
API=http://127.0.0.1:3082/orchestrator/api

if [ ! -f "$ROLE_MODEL" ]; then
    echo "No Serverless Inference model has been applied." >&2
    exit 1
fi

provider=$(jq -r '.provider // empty' "$ROLE_MODEL")
model=$(jq -r '.model // empty' "$ROLE_MODEL")
if [ -z "$provider" ] || [ -z "$model" ]; then
    echo "The recorded inference model is incomplete." >&2
    exit 1
fi

api_get() {
    curl -fsS -m 10 -H 'x-orchestrator-request: 1' "$API/$1"
}

wait_ready() {
    local i state
    for i in $(seq 1 90); do
        state=$(api_get state 2>/dev/null | jq -r '.health.runtime.state // empty' 2>/dev/null || true)
        case "$state" in
            ready|paused) return 0 ;;
        esac
        sleep 2
    done
    return 1
}

save_block() {
    local path=$1 revision=$2 value=$3 body out code
    body=$(jq -cn --argjson value "$value" --argjson revision "$revision" \
        '{value: $value, revision: $revision}')
    out=$(mktemp)
    code=$(curl -sS -m 60 -o "$out" -w '%{http_code}' -X PUT \
        -H 'x-orchestrator-request: 1' -H 'content-type: application/json' \
        --data "$body" "$API/settings/$path") || code=000
    if [ "${code:0:1}" != "2" ]; then
        echo "The panel refused the ${path} model (HTTP ${code}):" >&2
        cat "$out" >&2
        rm -f "$out"
        return 1
    fi
    rm -f "$out"
}

wait_ready || {
    echo "DSH Superagent is not answering on ${API}." >&2
    exit 1
}

settings=$(api_get settings)
for block in eval executor; do
    revision=$(jq -r ".blocks.${block}.revision" <<<"$settings")
    value=$(jq -c --arg provider "$provider" --arg model "$model" \
        "(.blocks.${block}.value // {}) | .model = {provider: \$provider, model: \$model}" <<<"$settings")
    save_block "$block" "$revision" "$value"
    settings=$(api_get settings)
done

echo "Eval and executor model: ${provider}/${model}"
