#!/bin/bash
# Update OpenClaw from npm, run post-upgrade doctor + gateway sync while the
# service is stopped, then restart the gateway.
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
#
# Doctor must run with the gateway stopped (state DB ownership). Manual repair:
#   systemctl stop openclaw
#   sudo -u openclaw -H openclaw doctor --fix --yes --non-interactive
#   systemctl start openclaw
#
# Schema jumps (e.g. agent DB v19 → current) need exclusive maintenance. Running
# doctor while the gateway is up, or continuing after a failed doctor, leaves
# sessions unavailable with "schema version N; run openclaw doctor --fix".
#
# If doctor fails after npm install, this script reinstalls the prior pin (when
# known) and restarts so the droplet is not left on a half-upgraded package.

set -euo pipefail

ENV_FILE=/opt/openclaw.env
OPENCLAW_HOME=/home/openclaw
OPENCLAW_USER=openclaw
OPENCLAW_UNIT=/etc/systemd/system/openclaw.service

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

# CVE-2026-111497 remediation + current OpenClaw engines:
#   Node >=24.22.1 <25  ||  >=26.12.1
# (VULN-5695 / VULN-5716 = internal tracker labels for that CVE.)
# Do not accept other majors (unknown patch floors / unsupported by OpenClaw).
node_meets_cve_and_engines() {
    command -v node >/dev/null 2>&1 || return 1
    # Prefer the NodeSource binary the gateway should use (/usr/bin/env node).
    local node_bin
    node_bin="$(command -v node)"
    if [ -x /usr/bin/node ]; then
        node_bin=/usr/bin/node
    fi
    "$node_bin" -e '
      function ge(a, b) {
        const pa = String(a).split(".").map((x) => parseInt(x, 10) || 0);
        const pb = String(b).split(".").map((x) => parseInt(x, 10) || 0);
        for (let i = 0; i < 3; i++) {
          if ((pa[i] || 0) > (pb[i] || 0)) return true;
          if ((pa[i] || 0) < (pb[i] || 0)) return false;
        }
        return true;
      }
      const v = process.versions.node;
      const maj = parseInt(v.split(".")[0], 10);
      const ok =
        (maj === 24 && ge(v, "24.22.1")) ||
        (maj === 26 && ge(v, "26.12.1"));
      process.exit(ok ? 0 : 1);
    ' 2>/dev/null
}

install_nodesource_24() {
    # Configure the apt repo with a signed keyring (do not curl|bash remote setup scripts).
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    chmod a+r /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list
    apt-get update -y
    # Plain install upgrades when a newer NodeSource build exists and installs
    # when missing. Do not use --only-upgrade alone (no-ops if nodejs absent).
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
}

# Keep gateway unit PATH aligned with the image unit so existing droplets pick
# up the /usr/bin-first ordering without waiting for a Marketplace rebuild.
ensure_openclaw_unit_node_path() {
    [ -f "$OPENCLAW_UNIT" ] || return 0

    if grep -qF 'PATH=/usr/bin:/bin:/home/openclaw/.openclaw/workspace/npm/bin' "$OPENCLAW_UNIT"; then
        return 0
    fi

    echo "Updating ${OPENCLAW_UNIT} PATH so gateway uses /usr/bin/node (CVE-2026-111497)..."
    python3 - "$OPENCLAW_UNIT" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
desired = (
    'Environment="PATH=/usr/bin:/bin:/home/openclaw/.openclaw/workspace/npm/bin:'
    '/home/openclaw/.openclaw/workspace/homebrew/bin:/usr/local/bin"'
)
new, n = re.subn(r'^Environment="PATH=.*"', desired, text, count=1, flags=re.M)
if n == 0:
    if re.search(r'^Environment="NODE_ENV=', text, flags=re.M):
        new = re.sub(
            r'^(Environment="NODE_ENV=.*")',
            r"\1\n" + desired,
            text,
            count=1,
            flags=re.M,
        )
    else:
        new = re.sub(r"^\[Service\]", "[Service]\n" + desired, text, count=1, flags=re.M)
path.write_text(new)
print(f"Updated {path}")
PY
    systemctl daemon-reload
}

ensure_node_for_openclaw() {
    ensure_openclaw_unit_node_path

    if node_meets_cve_and_engines; then
        echo "Node $(/usr/bin/node --version 2>/dev/null || node --version) meets CVE-2026-111497 + OpenClaw engines."
        return 0
    fi

    local current
    current="$(/usr/bin/node --version 2>/dev/null || node --version 2>/dev/null || echo 'missing')"
    echo "Node ${current} is below CVE-2026-111497 / OpenClaw minimum (need >=24.22.1 on 24.x, or >=26.12.1 on 26.x)."
    echo "Upgrading Node.js to 24.x via NodeSource apt repository (tracker refs VULN-5695 / VULN-5716)..."

    install_nodesource_24
    ensure_openclaw_unit_node_path

    if ! node_meets_cve_and_engines; then
        echo "❌ Error: Node still too old after upgrade ($(/usr/bin/node --version 2>/dev/null || node --version 2>/dev/null || echo missing))" >&2
        echo "   Expected >=24.22.1 (CVE-2026-111497). Check NodeSource node_24.x packages." >&2
        exit 1
    fi
    echo "Node upgraded to $(/usr/bin/node --version)."
}

# Stop systemd unit and any leftover gateway writers so doctor can take the
# agent/shared SQLite maintenance lease (required for schema migrations).
stop_openclaw_for_maintenance() {
    echo "Stopping OpenClaw service for maintenance..."
    systemctl stop openclaw || true

    local i
    for i in $(seq 1 30); do
        if ! systemctl is-active --quiet openclaw 2>/dev/null; then
            break
        fi
        sleep 1
    done

    # Custom unit is not always recognized as a "managed" Gateway by doctor;
    # kill residual writers that would still hold openclaw-agent.sqlite.
    pkill -u "$OPENCLAW_USER" -f 'openclaw gateway' 2>/dev/null || true
    sleep 1

    if systemctl is-active --quiet openclaw 2>/dev/null; then
        echo "❌ Error: openclaw.service is still active; cannot run doctor safely." >&2
        echo "   Try: sudo systemctl stop openclaw && sudo systemctl status openclaw" >&2
        exit 1
    fi
}

run_openclaw_doctor_fix() {
    # --fix/--yes enter repair maintenance; --non-interactive skips prompts.
    # HOME must be the openclaw user home so doctor finds ~/.openclaw state.
    sudo -u "$OPENCLAW_USER" -H env HOME="$OPENCLAW_HOME" \
        openclaw doctor --fix --yes --non-interactive
}

# After a failed post-upgrade doctor, restore the prior npm pin (when known) and
# try to bring the gateway back so the droplet is not left stopped on the new build.
rollback_after_doctor_failure() {
    local prior="$1"
    local failed="$2"

    echo "❌ Error: openclaw doctor --fix failed after installing openclaw@${failed}." >&2
    echo "   Agent DB schema migrations did not finish." >&2

    if [ -z "${prior}" ] || [ "${prior}" = "latest" ] || [ "${prior}" = "${failed}" ]; then
        echo "   No prior pin to restore. Gateway left stopped. Retry:" >&2
        echo "     sudo systemctl stop openclaw" >&2
        echo "     sudo -u openclaw -H openclaw doctor --fix --yes --non-interactive" >&2
        echo "     sudo systemctl start openclaw" >&2
        return 1
    fi

    echo "Restoring previous package openclaw@${prior} and restarting..." >&2
    if ! npm install -g "openclaw@${prior}"; then
        echo "❌ Error: rollback install of openclaw@${prior} failed; gateway left stopped." >&2
        echo "   Manual: sudo /opt/update-openclaw.sh --rollback" >&2
        return 1
    fi

    set_env_kv OPENCLAW_VERSION "v${prior}"
    if systemctl start openclaw; then
        echo "⚠️  Rolled back to v${prior} and restarted. Fix doctor issues before updating again." >&2
        echo "   Retry update later: sudo /opt/update-openclaw.sh" >&2
    else
        echo "❌ Error: rolled back package to v${prior} but failed to start openclaw." >&2
        echo "   Check: journalctl -u openclaw -xe" >&2
    fi
    return 1
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

stop_openclaw_for_maintenance

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

    # Re-assert stop after npm (and before doctor): writers must be down for
    # agent schema migrations (v19+ session-identity / creator-namespace).
    stop_openclaw_for_maintenance

    echo "Running post-upgrade doctor (gateway stopped)..."
    if run_openclaw_doctor_fix; then
        echo "Doctor repair completed."
    else
        rollback_after_doctor_failure "${BEFORE_VERSION:-}" "${INSTALLED_VERSION}"
        exit 1
    fi

    if [ -x /opt/sync-openclaw-gateway.sh ]; then
        echo "Syncing gateway token / trustedProxies / allowedOrigins..."
        if /opt/sync-openclaw-gateway.sh; then
            echo "Gateway config synced."
        else
            echo "⚠️  Warning: sync-openclaw-gateway.sh failed (continuing)." >&2
            echo "   Repair with: sudo /opt/ensure-openclaw-ready.sh" >&2
        fi
    fi

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
        echo "If Control UI or models misbehave: sudo /opt/ensure-openclaw-ready.sh"
        echo "  and re-apply inference if needed: sudo /opt/apply-inference-from-env.sh"
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
