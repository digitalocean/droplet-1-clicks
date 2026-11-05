#!/usr/bin/env bash
# The DigitalOcean Inference profile lists the chosen model first and never
# contains the model access key.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPLY="$SCRIPT_DIR/../files/opt/dsh-superagent/apply-inference-from-env.sh"

# shellcheck disable=SC1090
source "$APPLY"

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

if model_id_ok "minimax-m2.5" && model_id_ok "router:default" && ! model_id_ok "../etc/passwd" && ! model_id_ok ""; then
    echo "OK: model ids accept the inference catalog and reject path fragments"
else
    echo "FAIL: model id check"
    FAILURES=$((FAILURES + 1))
fi

ordered="$(ordered_inference_model_ids "kimi-k3" $'glm-5.3\nkimi-k3\nminimax-m2.5')"
assert_eq "$ordered" $'kimi-k3\nglm-5.3\nminimax-m2.5' "chosen model stays first and is not duplicated"

models="$(mktemp)"
printf '%s\n' "$ordered" >"$models"
patch="$(render_profile_patch "$models")"
rm -f "$models"
printf '%s\n' "$patch" | grep -q 'apiKeyEnv: MODEL_ACCESS_KEY'
echo "OK: the profile names the key variable"
if printf '%s\n' "$patch" | grep -q 'secret-key-value'; then
    echo "FAIL: a model access key must not be written into the profile"
    FAILURES=$((FAILURES + 1))
else
    echo "OK: the profile has no key value"
fi
first="$(printf '%s\n' "$patch" | awk '/^              - id: / { print $3; exit }')"
assert_eq "$first" "kimi-k3" "the chosen model is the first catalog entry"
printf '%s\n' "$patch" | grep -q 'baseURL: https://inference.do-ai.run/v1'
echo "OK: the gateway is the Serverless Inference endpoint"

env_file="$(mktemp)"
printf '%s\n' 'MODEL_ACCESS_KEY=secret' 'KEEP=yes' >"$env_file"
strip_inference_keys "$env_file" 600
assert_eq "$(cat "$env_file")" "KEEP=yes" "the access key is removed from the environment file"
rm -f "$env_file"

if [ "$FAILURES" -ne 0 ]; then
    echo "$FAILURES check(s) failed."
    exit 1
fi
echo "All inference profile checks passed."
