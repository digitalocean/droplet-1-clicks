#!/bin/bash
# Update Hermes Agent from GitHub release tags (OpenClaw-style helper).
#
# Usage:
#   /opt/hermes/update-hermes.sh              # install latest GitHub release
#   /opt/hermes/update-hermes.sh v2026.9.14   # install a specific release tag
#   /opt/hermes/update-hermes.sh latest       # same as no args
#
# HERMES_VERSION in /opt/hermes/hermes.env is the installed pin (updated after
# success).
#
# Tag-only shallow clones leave a detached HEAD without origin/main, which
# breaks bare `hermes update`. This helper expands remotes, fetches tags/main,
# and re-runs the official installer against the target release tag.

set -euo pipefail

ENV_FILE=/opt/hermes/hermes.env
HERMES_USER=${HERMES_USER:-hermes}
HERMES_HOME=${HERMES_HOME:-/home/hermes/.hermes}
HERMES_AGENT_DIR=${HERMES_AGENT_DIR:-/home/hermes/.hermes/hermes-agent}
HERMES_BIN=${HERMES_BIN:-/home/hermes/.local/bin/hermes}
LATEST_RELEASE_URL=https://github.com/NousResearch/hermes-agent/releases/latest
INSTALLER_BASE=https://raw.githubusercontent.com/NousResearch/hermes-agent

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 ${*:-}" >&2
    exit 1
fi

usage() {
    cat <<'EOF'
Usage: /opt/hermes/update-hermes.sh [version]

  (no args) / latest   Install the latest Hermes Agent GitHub release
  v2026.9.14 / 2026.9.14
                       Install that exact release tag
EOF
}

read_env_kv() {
    local key="$1" line val
    [ -f "$ENV_FILE" ] || return 1
    line=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1) || return 1
    val="${line#${key}=}"
    val="${val#\"}"
    val="${val%\"}"
    val="${val#\'}"
    val="${val%\'}"
    case "$val" in
        ''|*'${'*|PLACEHOLDER*) return 1 ;;
    esac
    printf '%s' "$val"
}

set_env_kv() {
    local key="$1" value="$2"
    touch "$ENV_FILE"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >>"$ENV_FILE"
    fi
}

normalize_version() {
    local v="$1"
    case "$v" in
        ''|Latest|LATEST|latest) printf '%s' "latest" ;;
        *)
            # Hermes release tags are vYYYY.M.D[.N]
            case "$v" in
                v*) printf '%s' "$v" ;;
                *) printf '%s' "v${v}" ;;
            esac
            ;;
    esac
}

resolve_latest_release_tag() {
    local tag
    tag="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$LATEST_RELEASE_URL" | sed 's#.*/##')"
    if [ -z "$tag" ] || [ "$tag" = "latest" ]; then
        echo "❌ Error: unable to resolve the latest Hermes release tag." >&2
        exit 1
    fi
    printf '%s' "$(normalize_version "$tag")"
}

current_installed_version() {
    local from_env from_cli
    from_env="$(read_env_kv HERMES_VERSION || true)"
    if [ -n "${from_env}" ] && [ "${from_env}" != "latest" ]; then
        normalize_version "$from_env"
        return 0
    fi

    if [ -x "$HERMES_BIN" ]; then
        # e.g. "Hermes Agent v0.21.3 (2026.9.14)" → v2026.9.14
        from_cli="$("$HERMES_BIN" --version 2>/dev/null | head -n 1 || true)"
        if [[ "$from_cli" =~ \(([0-9]{4}\.[0-9]+\.[0-9]+(\.[0-9]+)?)\) ]]; then
            normalize_version "${BASH_REMATCH[1]}"
            return 0
        fi
    fi

    if [ -d "$HERMES_AGENT_DIR/.git" ]; then
        from_cli="$(git -C "$HERMES_AGENT_DIR" describe --tags --exact-match HEAD 2>/dev/null || true)"
        if [ -n "$from_cli" ]; then
            normalize_version "$from_cli"
            return 0
        fi
    fi
    return 1
}

validate_version_ref() {
    local v="$1"
    case "$v" in
        *[!A-Za-z0-9._-]*)
            echo "❌ Error: unsupported Hermes version reference: $v" >&2
            exit 1
            ;;
    esac
}

prepare_git_remotes() {
    # Tag-only shallow clones only advertise the install tag. Expand remotes so
    # later `hermes update` / tag checkouts can see main and releases.
    if [ ! -d "$HERMES_AGENT_DIR/.git" ]; then
        return 0
    fi
    su - "$HERMES_USER" -c "
        set -e
        cd $(printf '%q' "$HERMES_AGENT_DIR")
        git remote set-branches origin '*' >/dev/null 2>&1 || true
        git fetch --unshallow origin >/dev/null 2>&1 || true
        git fetch origin main >/dev/null 2>&1 || true
        git fetch --tags origin >/dev/null 2>&1 || true
    " || true
}

install_hermes_ref() {
    local ref="$1"
    local installer
    installer="$(mktemp /tmp/hermes-install.XXXXXX.sh)"

    echo "Downloading Hermes installer for ${ref}..."
    if ! curl -fsSL "${INSTALLER_BASE}/${ref}/scripts/install.sh" -o "$installer"; then
        rm -f "$installer"
        echo "❌ Error: could not download installer for ${ref}." >&2
        echo "Check that the release tag exists, e.g. v2026.9.14" >&2
        exit 1
    fi
    chmod 0755 "$installer"

    echo "Installing Hermes Agent at ${ref}..."
    if ! su - "$HERMES_USER" -c "HERMES_HOME=$(printf '%q' "$HERMES_HOME") bash $(printf '%q' "$installer") --skip-setup --skip-browser --branch $(printf '%q' "$ref")"; then
        rm -f "$installer"
        echo "❌ Error: failed to install hermes@${ref}" >&2
        exit 1
    fi
    rm -f "$installer"

    if [ ! -x "$HERMES_BIN" ]; then
        echo "❌ Error: Hermes CLI not found after install (expected $HERMES_BIN)." >&2
        exit 1
    fi
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    --rollback|-r)
        echo "❌ Error: --rollback is not supported." >&2
        echo "Install a specific release instead, e.g.:" >&2
        echo "  sudo /opt/hermes/update-hermes.sh v2026.9.14" >&2
        exit 1
        ;;
    *)
        TARGET="$(normalize_version "${1:-latest}")"
        ;;
esac

validate_version_ref "$TARGET"

if [ "$TARGET" = "latest" ]; then
    TARGET="$(resolve_latest_release_tag)"
fi

BEFORE_VERSION="$(current_installed_version || true)"

echo "Updating Hermes Agent (target version: ${TARGET})..."

if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "latest" ]; then
    echo "Currently installed: ${BEFORE_VERSION}"
fi

if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" = "${TARGET}" ]; then
    echo "Already on ${TARGET}. Refreshing install and remediating npm advisories..."
fi

prepare_git_remotes
install_hermes_ref "$TARGET"
prepare_git_remotes

# Clear doctor npm advisories left by the release lockfile.
if [ -x /opt/hermes/remediate-npm.sh ]; then
    /opt/hermes/remediate-npm.sh || true
fi

INSTALLED_VERSION="$TARGET"
set_env_kv HERMES_VERSION "${INSTALLED_VERSION}"

echo ""
echo "✅ Hermes Agent updated successfully!"
echo "Version: ${INSTALLED_VERSION}"
su - "$HERMES_USER" -c "HERMES_HOME=$(printf '%q' "$HERMES_HOME") $(printf '%q' "$HERMES_BIN") --version" || true

echo "Update process completed."
