#!/usr/bin/env bash
# Unit tests for the shared DigitalOcean inference model-list helpers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/../files/var/lib/digitalocean/inference-models.sh"

if [ ! -f "$LIB" ]; then
    echo "FAIL: missing $LIB"
    exit 1
fi

# shellcheck source=../files/var/lib/digitalocean/inference-models.sh
. "$LIB"

FAILURES=0

assert_eq() {
    local actual="$1" expected="$2" msg="$3"
    if [ "$actual" = "$expected" ]; then
        echo "OK: $msg"
    else
        echo "FAIL: $msg"
        echo "  expected: $(printf '%q' "$expected")"
        echo "  actual:   $(printf '%q' "$actual")"
        FAILURES=$((FAILURES + 1))
    fi
}

assert_ok() {
    local msg="$1"
    shift
    if "$@"; then
        echo "OK: $msg"
    else
        echo "FAIL: $msg"
        FAILURES=$((FAILURES + 1))
    fi
}

assert_fail() {
    local msg="$1"
    shift
    if "$@"; then
        echo "FAIL: $msg"
        FAILURES=$((FAILURES + 1))
    else
        echo "OK: $msg"
    fi
}

echo "=== common inference-models.sh model list parsing ==="

FIXTURE='{
  "object": "list",
  "data": [
    {"id": "minimax-m2.5", "object": "model", "owned_by": "digitalocean"},
    {"id": "anthropic-claude-4.5-sonnet", "object": "model", "owned_by": "anthropic"},
    {"id": "fal-ai/fast-sdxl", "object": "model", "owned_by": "fal"},
    {"id": "text-embedding-3-small", "object": "model", "owned_by": "openai"},
    {"id": "kimi-k2.5", "object": "model", "owned_by": "moonshot"}
  ]
}'

ids="$(printf '%s' "$FIXTURE" | parse_inference_model_ids)"
assert_eq "$ids" "$(printf '%s\n' anthropic-claude-4.5-sonnet fal-ai/fast-sdxl kimi-k2.5 minimax-m2.5 text-embedding-3-small)" \
    "parse_inference_model_ids returns sorted unique ids"

chat_ids="$(printf '%s\n' "$ids" | filter_chat_inference_models)"
assert_eq "$chat_ids" "$(printf '%s\n' anthropic-claude-4.5-sonnet kimi-k2.5 minimax-m2.5)" \
    "filter_chat_inference_models drops embeddings and image/audio models"

assert_ok "chat model id is accepted" inference_model_is_chat kimi-k2.5
assert_fail "embedding model id is rejected" inference_model_is_chat text-embedding-3-small
assert_fail "fal image model id is rejected" inference_model_is_chat fal-ai/fast-sdxl
assert_fail "tts model id is rejected" inference_model_is_chat fal-ai/elevenlabs/tts/multilingual-v2

default="$(printf '%s\n' "$chat_ids" | pick_default_inference_model)"
assert_eq "$default" "anthropic-claude-4.5-sonnet" \
    "pick_default_inference_model uses the first remaining chat model"

chosen="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice 2)"
assert_eq "$chosen" "kimi-k2.5" \
    "resolve_inference_model_choice 2 selects the second listed model"

chosen="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice "")"
assert_eq "$chosen" "anthropic-claude-4.5-sonnet" \
    "empty selection keeps the default model"

chosen="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice kimi-k2.5)"
assert_eq "$chosen" "kimi-k2.5" \
    "typed model id is accepted when it is in the list"

if ! printf '%s\n' "$chat_ids" | resolve_inference_model_choice 99 >/dev/null 2>&1; then
    echo "OK: out-of-range selection is rejected"
else
    echo "FAIL: out-of-range selection should be rejected"
    FAILURES=$((FAILURES + 1))
fi

empty="$(printf '%s' '{"object":"list","data":[]}' | parse_inference_model_ids)"
assert_eq "$empty" "" "empty model list parses to no ids"

if [ "$FAILURES" -ne 0 ]; then
    echo
    echo "$FAILURES assertion(s) failed"
    exit 1
fi

echo
echo "All assertions passed"
