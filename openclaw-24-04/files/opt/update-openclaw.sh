#!/bin/bash
# Update OpenClaw from npm and restart the gateway service.
#
# Usage:
#   /opt/update-openclaw.sh              # install latest from npm
#   /opt/update-openclaw.sh v2026.9.3    # install a specific version
#   /opt/update-openclaw.sh latest       # same as no args
#   /opt/update-openclaw.sh --rollback   # reinstall previous version
#
# OPENCLAW_VERSION in /opt/openclaw.env is the installed pin (updated after
# success). OPENCLAW_VERSION_PREVIOUS is saved before each successful change
# so --rollback can restore it. Rollback reinstalls the prior npm package; it
# does not undo OpenClaw config/state migrations.

set -euo pipefail

ENV_FILE=/opt/openclaw.env

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 ${*:-}" >&2
    exit 1
fi

usage() {
    cat <<'EOF'
Usage: /opt/update-openclaw.sh [version|--rollback]

  (no args) / latest   Install the latest OpenClaw release from npm
  v2026.9.3 / 2026.9.3 Install that exact version
  --rollback           Reinstall OPENCLAW_VERSION_PREVIOUS from /opt/openclaw.env

Before each successful version change, the current pin is saved as
OPENCLAW_VERSION_PREVIOUS. Rollback restores that package only — it does not
undo config or workspace migrations applied by a newer release.
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
    local v="${1#v}"
    case "$v" in
        ''|Latest|LATEST|latest) printf '%s' "latest" ;;
        *) printf '%s' "$v" ;;
    esac
}

current_installed_version() {
    local from_env from_npm
    from_env="$(read_env_kv OPENCLAW_VERSION || true)"
    if [ -n "${from_env}" ]; then
        normalize_version "$from_env"
        return 0
    fi
    from_npm="$(npm list -g openclaw --depth=0 2>/dev/null | grep openclaw@ | sed 's/.*openclaw@//' | sed 's/ .*//' || true)"
    if [ -n "${from_npm}" ]; then
        printf '%s' "$from_npm"
        return 0
    fi
    return 1
}

# Current OpenClaw engines: >=24.16.0 <25 || >=26.1.0
node_meets_openclaw_engines() {
    command -v node >/dev/null 2>&1 || return 1
    node -e '
      const [maj, min] = process.versions.node.split(".").map(Number);
      const ok =
        (maj === 24 && min >= 16) ||
        (maj === 26 && min >= 1) ||
        maj > 26;
      process.exit(ok ? 0 : 1);
    ' 2>/dev/null
}

ensure_node_for_openclaw() {
    if node_meets_openclaw_engines; then
        echo "Node $(node --version) meets OpenClaw requirements."
        return 0
    fi

    local current
    current="$(node --version 2>/dev/null || echo 'missing')"
    echo "OpenClaw requires Node >=24.16.0 <25 or >=26.1.0 (found ${current})."
    echo "Upgrading Node.js to 24.x..."
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
    apt-get install -y nodejs

    if ! node_meets_openclaw_engines; then
        echo "❌ Error: Node still too old after upgrade ($(node --version 2>/dev/null || echo missing))" >&2
        exit 1
    fi
    echo "Node upgraded to $(node --version)."
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    --rollback|-r)
        MODE="rollback"
        PREV="$(read_env_kv OPENCLAW_VERSION_PREVIOUS || true)"
        if [ -z "${PREV}" ]; then
            echo "❌ Error: OPENCLAW_VERSION_PREVIOUS is not set in ${ENV_FILE}." >&2
            echo "Cannot rollback. Install a specific version instead, e.g.:" >&2
            echo "  sudo /opt/update-openclaw.sh v2026.9.3" >&2
            exit 1
        fi
        TARGET="$(normalize_version "$PREV")"
        ;;
    *)
        MODE="update"
        TARGET="$(normalize_version "${1:-latest}")"
        ;;
esac

if [ "$MODE" = "rollback" ]; then
    echo "Rolling back OpenClaw to previous version: v${TARGET}..."
else
    echo "Updating OpenClaw (target version: ${TARGET})..."
fi

BEFORE_VERSION="$(current_installed_version || true)"
if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "latest" ]; then
    echo "Currently installed: v${BEFORE_VERSION}"
fi

ensure_node_for_openclaw

echo "Stopping OpenClaw service..."
systemctl stop openclaw || true

echo "Installing openclaw@${TARGET} from npm..."
if npm install -g "openclaw@${TARGET}"; then
    echo "OpenClaw package install succeeded."

    INSTALLED_VERSION="$(npm list -g openclaw --depth=0 2>/dev/null | grep openclaw@ | sed 's/.*openclaw@//' | sed 's/ .*//' || true)"
    if [ -z "${INSTALLED_VERSION}" ]; then
        echo "❌ Error: openclaw installed but version could not be detected" >&2
        systemctl start openclaw || true
        exit 1
    fi

    # Save previous pin only when the installed version actually changes.
    if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "latest" ] \
        && [ "${BEFORE_VERSION}" != "${INSTALLED_VERSION}" ]; then
        set_env_kv OPENCLAW_VERSION_PREVIOUS "v${BEFORE_VERSION}"
        echo "Saved previous version for rollback: v${BEFORE_VERSION}"
    fi
    set_env_kv OPENCLAW_VERSION "v${INSTALLED_VERSION}"

    echo "Starting OpenClaw..."
    if systemctl start openclaw; then
        if [ "$MODE" = "rollback" ]; then
            echo "✅ OpenClaw rolled back and restarted successfully!"
        else
            echo "✅ OpenClaw updated and restarted successfully!"
        fi
        echo "Version: ${INSTALLED_VERSION}"
        if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "${INSTALLED_VERSION}" ]; then
            echo "Rollback (if needed): sudo /opt/update-openclaw.sh --rollback"
        fi
    else
        echo "❌ Error: Failed to restart OpenClaw" >&2
        echo "Check logs with: journalctl -u openclaw -xe" >&2
        exit 1
    fi
else
    echo "❌ Error: Failed to install openclaw@${TARGET}" >&2
    systemctl start openclaw || true
    exit 1
fi

echo "Update process completed."
