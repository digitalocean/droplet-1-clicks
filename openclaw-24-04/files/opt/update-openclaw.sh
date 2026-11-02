#!/bin/bash
# Update OpenClaw to the latest npm release, run post-upgrade doctor + gateway
# sync while the service is stopped, then restart the gateway.
#
# Usage:
#   /opt/update-openclaw.sh
#
# OPENCLAW_VERSION in /opt/openclaw.env is updated after a successful install.
#
# Doctor must run with the gateway stopped (state DB ownership). The 1-Click
# unit is root-owned/custom (not CLI-managed), so doctor needs:
#   OPENCLAW_SERVICE_REPAIR_POLICY=external
# Manual repair:
#   systemctl stop openclaw
#   sudo -u openclaw -H env HOME=/home/openclaw OPENCLAW_SERVICE_REPAIR_POLICY=external \
#     openclaw doctor --fix --yes --non-interactive
#   systemctl start openclaw
#
# If doctor fails after npm install, the gateway is left stopped on the newly
# installed package for manual repair.

set -euo pipefail

ENV_FILE=/opt/openclaw.env
OPENCLAW_HOME=/home/openclaw
OPENCLAW_USER=openclaw
OPENCLAW_UNIT=/etc/systemd/system/openclaw.service

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

usage() {
    cat <<'EOF'
Usage: /opt/update-openclaw.sh

Installs the latest OpenClaw release from npm. Stops the gateway, runs
doctor --fix with OPENCLAW_SERVICE_REPAIR_POLICY=external, syncs gateway
config, and restarts.
EOF
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

# True if any openclaw gateway writer is still alive for the service user.
gateway_writers_still_running() {
    pgrep -u "$OPENCLAW_USER" -f 'openclaw gateway' >/dev/null 2>&1 \
        || pgrep -u "$OPENCLAW_USER" -f 'openclaw/.*/dist/index.js gateway' >/dev/null 2>&1
}

# Stop systemd unit and any leftover gateway writers so doctor can take the
# agent/shared SQLite maintenance lease (required for schema migrations).
# Script remains the service owner; doctor uses OPENCLAW_SERVICE_REPAIR_POLICY=external.
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

    # Custom unit is not CLI-managed; kill residual writers that would still
    # hold openclaw-agent.sqlite / confuse doctor offline checks.
    pkill -u "$OPENCLAW_USER" -f 'openclaw gateway' 2>/dev/null || true
    pkill -u "$OPENCLAW_USER" -f 'openclaw/.*/dist/index.js gateway' 2>/dev/null || true

    for i in $(seq 1 15); do
        if ! gateway_writers_still_running; then
            break
        fi
        sleep 1
    done

    if gateway_writers_still_running; then
        echo "⚠️  Warning: residual OpenClaw gateway processes still present; sending SIGKILL..." >&2
        pkill -9 -u "$OPENCLAW_USER" -f 'openclaw gateway' 2>/dev/null || true
        pkill -9 -u "$OPENCLAW_USER" -f 'openclaw/.*/dist/index.js gateway' 2>/dev/null || true
        sleep 1
    fi

    if systemctl is-active --quiet openclaw 2>/dev/null; then
        echo "❌ Error: openclaw.service is still active; cannot run doctor safely." >&2
        echo "   Try: sudo systemctl stop openclaw && sudo systemctl status openclaw" >&2
        exit 1
    fi

    if gateway_writers_still_running; then
        echo "❌ Error: OpenClaw gateway processes still running after stop; cannot run doctor." >&2
        echo "   Inspect: ps -u ${OPENCLAW_USER} -f | grep -E 'openclaw|gateway'" >&2
        exit 1
    fi

    echo "Gateway stopped (systemd inactive, no residual writers)."
}

run_openclaw_doctor_fix() {
    # --fix/--yes enter repair maintenance; --non-interactive skips prompts.
    # HOME must be the openclaw user home so doctor finds ~/.openclaw state.
    # OPENCLAW_SERVICE_REPAIR_POLICY=external: 1-Click openclaw.service is
    # root-owned/custom; doctor must not try to own its lifecycle.
    sudo -u "$OPENCLAW_USER" -H env HOME="$OPENCLAW_HOME" \
        OPENCLAW_SERVICE_REPAIR_POLICY=external \
        openclaw doctor --fix --yes --non-interactive
}

case "${1:-}" in
    '' )
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        echo "❌ Error: this script installs latest only (no arguments)." >&2
        usage >&2
        exit 1
        ;;
esac

echo "Updating OpenClaw to latest from npm..."

ensure_node_for_openclaw
stop_openclaw_for_maintenance

echo "Installing openclaw@latest from npm..."
if npm install -g openclaw@latest; then
    echo "OpenClaw package install succeeded."

    INSTALLED_VERSION="$(npm list -g openclaw --depth=0 2>/dev/null | grep openclaw@ | sed 's/.*openclaw@//' | sed 's/ .*//' || true)"
    if [ -z "${INSTALLED_VERSION}" ]; then
        echo "❌ Error: openclaw installed but version could not be detected" >&2
        systemctl start openclaw || true
        exit 1
    fi

    set_env_kv OPENCLAW_VERSION "v${INSTALLED_VERSION}"

    # Re-assert stop after npm (and before doctor): writers must be down for
    # agent schema migrations (v19+ session-identity / creator-namespace).
    stop_openclaw_for_maintenance

    echo "Running post-upgrade doctor (gateway stopped)..."
    if run_openclaw_doctor_fix; then
        echo "Doctor repair completed."
    else
        echo "❌ Error: openclaw doctor --fix failed after installing openclaw@${INSTALLED_VERSION}." >&2
        echo "   Schema migrations / repair did not finish (see doctor output above)." >&2
        echo "   Docs: https://docs.openclaw.ai/reference/database-schemas" >&2
        echo "   Gateway left stopped on openclaw@${INSTALLED_VERSION}. Retry:" >&2
        echo "     sudo systemctl stop openclaw" >&2
        echo "     sudo -u openclaw -H env HOME=/home/openclaw OPENCLAW_SERVICE_REPAIR_POLICY=external \\" >&2
        echo "       openclaw doctor --fix --yes --non-interactive" >&2
        echo "     sudo systemctl start openclaw" >&2
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
        echo "✅ OpenClaw updated and restarted successfully!"
        echo "Version: ${INSTALLED_VERSION}"
        echo "If Control UI or models misbehave: sudo /opt/ensure-openclaw-ready.sh"
        echo "  and re-apply inference if needed: sudo /opt/apply-inference-from-env.sh"
    else
        echo "❌ Error: Failed to restart OpenClaw" >&2
        echo "Check logs with: journalctl -u openclaw -xe" >&2
        exit 1
    fi
else
    echo "❌ Error: Failed to install openclaw@latest" >&2
    systemctl start openclaw || true
    exit 1
fi

echo "Update process completed."
