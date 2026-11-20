#!/usr/bin/env bash
# DigitalOcean Inference must list its own models, hide Claude's catalog,
# and open new threads on the chosen model only when one was selected.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPLY="$SCRIPT_DIR/../files/opt/apply-inference-from-env.sh"

parser="$(mktemp)"
trap 'rm -f "$parser"' EXIT
sed -n '/^claude_builtin_model_slugs()/,/^}/p' "$APPLY" > "$parser"
sed -n '/^ordered_inference_model_ids()/,/^}/p' "$APPLY" >> "$parser"
sed -n '/^hidden_claude_slugs()/,/^}/p' "$APPLY" >> "$parser"
sed -n '/^merge_inference_settings()/,/^}/p' "$APPLY" >> "$parser"
# shellcheck disable=SC1090
source "$parser"

FAILURES=0
assert_eq() {
  local actual="$1" expected="$2" message="$3"
  if [ "$actual" = "$expected" ]; then
    echo "OK: $message"
  else
    echo "FAIL: $message"
    echo "  expected: $(printf '%q' "$expected")"
    echo "  actual:   $(printf '%q' "$actual")"
    FAILURES=$((FAILURES + 1))
  fi
}

ordered="$(ordered_inference_model_ids "kimi-k3" $'glm-5.3\nkimi-k3\nanthropic-claude-4.6-sonnet')"
assert_eq "$ordered" $'kimi-k3\nglm-5.3\nanthropic-claude-4.6-sonnet' "chosen model stays first and is not duplicated"

hidden="$(T3_RUNTIME_ROOT=/nonexistent hidden_claude_slugs $'kimi-k3\nclaude-opus-5-5')"
printf '%s\n' "$hidden" | grep -qx 'claude-sonnet-5-5'
echo "OK: Claude catalog slugs are hidden"
if printf '%s\n' "$hidden" | grep -qx 'claude-opus-5-5'; then
  echo "FAIL: an inference id that matches a Claude slug must stay visible"
  FAILURES=$((FAILURES + 1))
else
  echo "OK: an inference id is not hidden"
fi
if printf '%s\n' "$hidden" | grep -qx 'kimi-k3'; then
  echo "FAIL: inference models must not be treated as Claude models"
  FAILURES=$((FAILURES + 1))
else
  echo "OK: inference models are not hidden"
fi

tmp="$(mktemp)"
printf '%s\n' '{"providerInstances":{"claudeAgent":{"driver":"claudeAgent"}},"defaultModelSelection":{"instanceId":"codex","model":"gpt-5"}}' > "$tmp"
models='["kimi-k3","glm-5.3"]'
hidden_json='["claude-opus-5-5","claude-sonnet-5-5"]'
merge_inference_settings "$tmp" "$models" "$hidden_json" "kimi-k3" 1 "key" "https://inference.do-ai.run" "/home/t3/.claude-digitalocean" > "${tmp}.out"
mv "${tmp}.out" "$tmp"
assert_eq "$(jq -r '.defaultModelSelection.instanceId' "$tmp")" "digitalocean-inference" "an explicit model selects DigitalOcean Inference"
assert_eq "$(jq -r '.defaultModelSelection.model' "$tmp")" "kimi-k3" "an explicit model is the thread default"
assert_eq "$(jq -r '.providerInstances["digitalocean-inference"].config.customModels | join(",")' "$tmp")" "kimi-k3,glm-5.3" "the picker receives the inference catalog"
assert_eq "$(jq -r '.providerModelPreferences["digitalocean-inference"].hiddenModels | join(",")' "$tmp")" "claude-opus-5-5,claude-sonnet-5-5" "Claude catalog slugs are stored as hidden"
assert_eq "$(jq -r '.providerInstances.claudeAgent.driver' "$tmp")" "claudeAgent" "the native Claude provider is left in place"

merge_inference_settings "$tmp" "$models" "$hidden_json" "kimi-k3" 0 "key" "https://inference.do-ai.run" "/home/t3/.claude-digitalocean" > "${tmp}.out"
mv "${tmp}.out" "$tmp"
assert_eq "$(jq -r '.defaultModelSelection' "$tmp")" "null" "clearing the choice returns to the default provider"

printf '%s\n' '{"providerInstances":{},"defaultModelSelection":{"instanceId":"codex","model":"gpt-5"}}' > "$tmp"
merge_inference_settings "$tmp" "$models" "$hidden_json" "glm-5.3" 0 "key" "https://inference.do-ai.run" "/home/t3/.claude-digitalocean" > "${tmp}.out"
mv "${tmp}.out" "$tmp"
assert_eq "$(jq -r '.defaultModelSelection.instanceId + " " + .defaultModelSelection.model' "$tmp")" "codex gpt-5" "another provider default is kept when no model was chosen"

rm -f "$tmp"
if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES check(s) failed."
  exit 1
fi
echo "All inference settings checks passed."
