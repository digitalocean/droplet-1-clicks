#!/bin/bash
# DSH Superagent first-login setup.
#
# Asks for what only the operator can provide, stores it on this Droplet, and
# configures DSH Superagent through its local management API. Safe to re-run
# with --force (for example, to change the repository or the allowed users).
set -uo pipefail

APP_USER=superagent
APP_HOME=/home/superagent
CONFIG_DIR=$APP_HOME/.config/dsh-superagent
ENV_FILE=$CONFIG_DIR/env
MARKER=$CONFIG_DIR/configured
GH_AGENT=/opt/dsh-superagent/gh-agent
CTL=/opt/dsh-superagent/superagent-ctl.sh
SERVICE=dsh-superagent.service
API=http://127.0.0.1:3082/orchestrator/api

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi
if [ "${1:-}" != "--force" ] && [ -f "$MARKER" ]; then
    echo "DSH Superagent is already set up. Run /etc/setup_wizard.sh --force to change it."
    exit 0
fi

die() {
    echo >&2
    echo "Setup stopped: $*" >&2
    echo "Run /etc/setup_wizard.sh again once this is fixed." >&2
    exit 1
}

# Run a command as the application user with a clean environment.
as_app() {
    runuser -u "$APP_USER" -- env -i \
        HOME="$APP_HOME" USER="$APP_USER" LOGNAME="$APP_USER" \
        PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 TERM="${TERM:-xterm}" "$@"
}

api_get() {
    curl -fsS -m 10 -H 'x-orchestrator-request: 1' "$API/$1"
}

# Wait until the runtime answers: "ready", or "paused" while waiting for setup.
wait_ready() {
    local i state
    for i in $(seq 1 90); do
        state=$(api_get state 2>/dev/null | jq -r '.health.runtime.state // empty' 2>/dev/null)
        case "$state" in
            ready|paused) return 0 ;;
        esac
        sleep 2
    done
    return 1
}

# Save one settings block. $1 = block path, $2 = its revision, $3 = its new value (JSON).
save_block() {
    local path=$1 revision=$2 value=$3 body out code restarting
    if [ -z "$revision" ] || [ "$revision" = "null" ]; then
        echo "The panel did not report a revision for $path." >&2
        return 1
    fi
    body=$(jq -cn --argjson value "$value" --argjson revision "$revision" \
        '{value: $value, revision: $revision}') || return 1
    out=$(mktemp)
    code=$(curl -sS -m 60 -o "$out" -w '%{http_code}' -X PUT \
        -H 'x-orchestrator-request: 1' -H 'content-type: application/json' \
        --data "$body" "$API/settings/$path") || code=000
    if [ "${code:0:1}" != "2" ]; then
        echo "The panel refused the $path setting (HTTP $code):" >&2
        cat "$out" >&2
        echo >&2
        rm -f "$out"
        return 1
    fi
    restarting=$(jq -r '.restarting // false' "$out" 2>/dev/null)
    rm -f "$out"
    if [ "$restarting" = "true" ]; then
        # Saving the GitHub source restarts the runtime; wait for it to come back.
        sleep 5
        wait_ready || return 1
    fi
    return 0
}

save_github() {
    local settings rev value
    settings=$(api_get settings) || return 1
    rev=$(jq -r '.sources[] | select(.id == "github") | .revision' <<<"$settings")
    value=$(jq -c --arg repo "$1" --arg cli "$2" \
        '(.sources[] | select(.id == "github") | .value) // {}
         | .enabled = true
         | .config = ((.config // {}) + {repository: $repo, cli: $cli})' <<<"$settings") || return 1
    save_block "source:github" "$rev" "$value"
}

save_policy() {
    local settings rev value
    settings=$(api_get settings) || return 1
    rev=$(jq -r '.blocks.policy.revision' <<<"$settings")
    value=$(jq -c --argjson ids "$1" \
        '(.blocks.policy.value // {}) | .sources.github.allowed = ($ids | map({id: .}))' <<<"$settings") || return 1
    save_block "policy" "$rev" "$value"
}

save_executor() {
    local settings rev value
    settings=$(api_get settings) || return 1
    rev=$(jq -r '.blocks.executor.revision' <<<"$settings")
    value=$(jq -c --arg prepare "$1" \
        '(.blocks.executor.value // {}) | .prepare = $prepare' <<<"$settings") || return 1
    save_block "executor" "$rev" "$value"
}

save_model_key() {
    install -d -o "$APP_USER" -g "$APP_USER" -m 0755 "$APP_HOME/.config"
    install -d -o "$APP_USER" -g "$APP_USER" -m 0700 "$CONFIG_DIR"
    (umask 077 && printf 'DEEPSEEK_API_KEY=%q\n' "$1" > "$ENV_FILE")
    chown "$APP_USER:$APP_USER" "$ENV_FILE"
    chmod 0600 "$ENV_FILE"
}

model_key_saved() {
    [ -f "$ENV_FILE" ] && grep -q '^DEEPSEEK_API_KEY=.' "$ENV_FILE"
}

cat <<'EOF'

========================================================================
  DSH Superagent setup
========================================================================

This takes a few minutes. You will need:

  1. A DigitalOcean model access key, or a DeepSeek API key.
  2. A GitHub account for the agent. Use a dedicated account, not yours.
  3. The repository the agent should work on, as owner/name.
  4. Your own GitHub login, which may ask the agent for work.

Secrets are stored only on this Droplet, readable by the superagent user.

EOF

install -d -o "$APP_USER" -g "$APP_USER" -m 0755 "$APP_HOME/.config"
install -d -o "$APP_USER" -g "$APP_USER" -m 0700 "$CONFIG_DIR"

# 1. Model provider. DigitalOcean Inference is the default. A DeepSeek key remains available.
USE_INFERENCE=0
INFERENCE_MARKER=/var/lib/digitalocean/dsh-superagent-inference-configured
echo "Step 1 of 4: model provider"
if [ -f "$INFERENCE_MARKER" ] && [ "${1:-}" != "--force" ]; then
    echo "DigitalOcean Serverless Inference is already configured."
    USE_INFERENCE=1
else
    cat <<'EOF'

How should DSH Superagent call a model?

  1) DigitalOcean Serverless Inference
  2) DeepSeek API key

Create a model access key at:
  https://cloud.digitalocean.com/model-studio/manage-keys

EOF
    read -rp "Enter 1 or 2 [default: 1]: " PROVIDER_SEL
    case "${PROVIDER_SEL}" in
        2)
            read -rsp "Paste your DeepSeek API key (hidden; press Enter to skip): " DEEPSEEK_API_KEY
            echo
            if [ -n "$DEEPSEEK_API_KEY" ]; then
                save_model_key "$DEEPSEEK_API_KEY"
                echo "Saved."
            elif model_key_saved; then
                echo "Keeping the key already saved."
            else
                echo "Skipped. Add it later: sudo -u superagent nano $ENV_FILE, then systemctl restart $SERVICE."
            fi
            unset DEEPSEEK_API_KEY
            ;;
        *)
            read -rsp "Paste your model access key (hidden; press Enter to keep the saved key): " MODEL_ACCESS_KEY
            echo
            if [ -z "${MODEL_ACCESS_KEY:-}" ] && [ ! -f "$INFERENCE_MARKER" ]; then
                die "A model access key is required for DigitalOcean Serverless Inference."
            fi
            INFERENCE_MODEL=""
            list_key="${MODEL_ACCESS_KEY:-}"
            if [ -z "$list_key" ] && [ -f /opt/dsh-superagent/dsh-superagent-inference.env ]; then
                list_key=$(grep -E '^MODEL_ACCESS_KEY=' /opt/dsh-superagent/dsh-superagent-inference.env | tail -n 1 | cut -d= -f2- || true)
                list_key="${list_key#\'}"; list_key="${list_key%\'}"
            fi
            chat_ids=""
            if [ -n "$list_key" ] && [ -f /var/lib/digitalocean/inference-models.sh ]; then
                # shellcheck source=/var/lib/digitalocean/inference-models.sh
                . /var/lib/digitalocean/inference-models.sh
                echo "Fetching chat models from DigitalOcean Serverless Inference..."
                chat_ids="$(list_chat_inference_models "$list_key" || true)"
            fi
            if [ -n "$chat_ids" ]; then
                echo
                i=1
                while IFS= read -r line; do
                    [ -n "$line" ] || continue
                    printf '  %2d) %s\n' "$i" "$line"
                    i=$((i + 1))
                done <<<"$chat_ids"
                echo
                read -rp "Selection [Enter for the first model]: " SEL
                if ! INFERENCE_MODEL="$(printf '%s\n' "$chat_ids" | resolve_inference_model_choice "$SEL")"; then
                    die "That was not one of the listed models."
                fi
            else
                echo "The model list is unavailable. Enter a model id, or press Enter to keep the saved model."
                read -rp "Model id: " INFERENCE_MODEL
            fi
            unset list_key chat_ids
            if [ -n "${MODEL_ACCESS_KEY:-}" ]; then
                export MODEL_ACCESS_KEY
            fi
            export INFERENCE_MODEL
            /opt/dsh-superagent/apply-inference-from-env.sh \
                || die "DigitalOcean Serverless Inference was not configured."
            unset MODEL_ACCESS_KEY INFERENCE_MODEL
            USE_INFERENCE=1
            ;;
    esac
fi

# 2. Agent GitHub account
echo
echo "Step 2 of 4: the agent's GitHub account"
agent_login=$(as_app "$GH_AGENT" api user --jq .login 2>/dev/null || true)
if [ -n "$agent_login" ]; then
    echo "Already signed in as @${agent_login}."
else
    echo "Sign in as the AGENT account. Follow the one-time code shown below in a browser."
    as_app "$GH_AGENT" auth login --hostname github.com --git-protocol https \
        --web --insecure-storage || die "The GitHub sign-in did not finish."
    agent_login=$(as_app "$GH_AGENT" api user --jq .login 2>/dev/null || true)
fi
[ -n "$agent_login" ] || die "The agent's GitHub account could not be read."

# 3. Repository and allowed users
echo
echo "Step 3 of 4: repository and who may ask for work"
while true; do
    read -rp "Repository the agent works on (owner/name): " REPO
    if [[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
        break
    fi
    echo "Use the form owner/name, for example acme/widgets."
done

while true; do
    read -rp "Your GitHub login(s) who may ask the agent for work (comma-separated): " OPERATORS_RAW
    OPERATORS_JSON=$(printf '%s\n' "$OPERATORS_RAW" | tr ',' '\n' \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' \
        | jq -R . | jq -sc . 2>/dev/null)
    valid=1
    while IFS= read -r login; do
        if ! [[ "$login" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,38}(\[bot\])?$ ]]; then
            valid=0
        fi
    done < <(jq -r '.[]' <<<"${OPERATORS_JSON:-[]}")
    if [ "$valid" = 1 ] && [ "$(jq 'length' <<<"${OPERATORS_JSON:-[]}")" -gt 0 ]; then
        break
    fi
    echo "Enter at least one GitHub login, for example your own."
done

# The agent must be able to write to the repository before setup can succeed.
echo
echo "Invite @${agent_login} to ${REPO} with write access, then accept the invitation"
echo "while signed in as @${agent_login} in a browser."
while [ "$(as_app "$GH_AGENT" api "repos/$REPO" --jq .permissions.push 2>/dev/null || true)" != "true" ]; do
    echo "@${agent_login} cannot push to ${REPO} yet."
    read -rp "Press Enter to check again, or type q to stop: " answer
    [ "$answer" = "q" ] && die "The agent has no write access to $REPO yet."
done
echo "The agent can push to ${REPO}."

# Local clone that each Ticket's worktree is created from.
CLONE_NAME=${REPO#*/}
CLONE_DIR=$APP_HOME/src/$CLONE_NAME
if [ ! -d "$CLONE_DIR/.git" ]; then
    echo "Cloning ${REPO} to ${CLONE_DIR}..."
    if ! as_app git -c credential.helper= \
        -c "credential.helper=!$GH_AGENT auth git-credential" \
        clone --quiet "https://github.com/${REPO}.git" "$CLONE_DIR"; then
        rm -rf "$CLONE_DIR"
        die "Could not clone ${REPO}."
    fi
fi

# 4. Start the service and save its settings through the panel's API.
echo
echo "Step 4 of 4: starting DSH Superagent and saving its settings"
systemctl restart "$SERVICE" || true
wait_ready || die "DSH Superagent did not answer on $API. See: systemctl status $SERVICE"

PREPARE_CMD='git -C "$CLONE" fetch --no-tags "https://github.com/$DSH_SUPERAGENT_GITHUB_REPOSITORY.git" "${DSH_SUPERAGENT_GITHUB_PR_HEAD:-HEAD}:refs/dsh-superagent/$DSH_SUPERAGENT_TICKET" && git -C "$CLONE" worktree add -b "agent/$DSH_SUPERAGENT_NAME" "$DSH_SUPERAGENT_DIR" "refs/dsh-superagent/$DSH_SUPERAGENT_TICKET"'
PREPARE_CMD=${PREPARE_CMD//\$CLONE/$CLONE_DIR}

save_github "$REPO" "$GH_AGENT" || die "The GitHub source was not saved. Fix the problem above, then re-run."
save_policy "$OPERATORS_JSON" || die "The allowed users were not saved. Fix the problem above, then re-run."
save_executor "$PREPARE_CMD" || die "The execution settings were not saved. Fix the problem above, then re-run."
if [ "$USE_INFERENCE" = "1" ]; then
    /opt/dsh-superagent/push-inference-model.sh \
        || die "The DigitalOcean Inference model was not saved. Fix the problem above, then re-run."
fi

setup_problem=$(api_get state | jq -c '.setup.problem // empty')
if [ -n "$setup_problem" ]; then
    die "DSH Superagent still reports a setup problem: $setup_problem"
fi

install -o "$APP_USER" -g "$APP_USER" -m 0600 /dev/null "$MARKER"

if [ "$USE_INFERENCE" = "1" ]; then
    key_line="DigitalOcean Serverless Inference"
elif model_key_saved; then
    key_line="DeepSeek API key saved"
else
    key_line="not set (see the note in step 1)"
fi

cat <<EOF

========================================================================
  DSH Superagent is set up
========================================================================

  Agent account:   @${agent_login}
  Repository:      ${REPO}
  May ask for work: ${OPERATORS_RAW}
  Clone:           ${CLONE_DIR}
  Model:           ${key_line}

Next:
  1. Open the panel through an SSH tunnel from your computer:
       ssh -L 3082:127.0.0.1:3082 root@<droplet-ip>
     Then run /opt/dsh-superagent/status-dsh-superagent.sh on the Droplet
     for the panel URL.
  2. Comment "@${agent_login} <request>" on an Issue in ${REPO}.
     A Ticket appears on the panel's Overview within about a minute.

EOF
