#!/bin/bash
# Update OpenClaw from npm, run post-upgrade doctor + gateway sync while the
# service is stopped, then restart the gateway.
#
# Usage:
#   /opt/update-openclaw.sh              # install latest from npm
#   /opt/update-openclaw.sh v2026.9.3    # install a specific version
#   /opt/update-openclaw.sh latest       # same as no args
#   /opt/update-openclaw.sh --rollback   # reinstall previous version + state
#
# OPENCLAW_VERSION in /opt/openclaw.env is the installed pin (updated after
# success). OPENCLAW_VERSION_PREVIOUS is saved before each successful change
# so --rollback can restore it.
#
# OpenClaw SQLite schemas migrate forward-only. Downgrading the npm package
# alone cannot undo agent/shared DB migrations (doctor refuses "newer schema").
# Before each upgrade this script snapshots schema-critical state under
# /var/lib/openclaw/update-backups/v<version>/. Rollback / downgrade restores
# that snapshot with the matching package. Without a snapshot, downgrade is
# refused and the current install is left running.
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
# If doctor fails after an upgrade install, this script restores the prior
# package AND the pre-update state snapshot (when available), then restarts.

set -euo pipefail

ENV_FILE=/opt/openclaw.env
OPENCLAW_HOME=/home/openclaw
OPENCLAW_USER=openclaw
OPENCLAW_UNIT=/etc/systemd/system/openclaw.service
STATE_DIR="${OPENCLAW_HOME}/.openclaw"
BACKUP_ROOT=/var/lib/openclaw/update-backups
# Config + DBs that carry schema / writer stamps. Workspace (npm/homebrew/skills)
# is large and not required for schema-compatible rollback.
STATE_BACKUP_ITEMS=(openclaw.json state agents credentials client)

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 ${*:-}" >&2
    exit 1
fi

usage() {
    cat <<'EOF'
Usage: /opt/update-openclaw.sh [version|--rollback]

  (no args) / latest   Install the latest OpenClaw release from npm
  v2026.9.3 / 2026.9.3 Install that exact version
  --rollback           Reinstall OPENCLAW_VERSION_PREVIOUS + its state snapshot

Before each upgrade, the current pin is saved as OPENCLAW_VERSION_PREVIOUS and
schema-critical state is snapshotted under /var/lib/openclaw/update-backups/.
Rollback restores that package and snapshot together. OpenClaw DB schemas are
forward-only — package-only downgrades will fail doctor; a pre-update snapshot
is required. Post-upgrade data is discarded on rollback.
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

# True when installing $2 would move backward from $1 (sort -V).
is_version_downgrade() {
    local from="$1" to="$2" first
    [ -n "$from" ] && [ -n "$to" ] || return 1
    [ "$to" = "latest" ] && return 1
    [ "$from" = "latest" ] && return 1
    [ "$from" = "$to" ] && return 1
    first="$(printf '%s\n%s\n' "$from" "$to" | sort -V | head -n1)"
    [ "$first" = "$to" ]
}

backup_path_for() {
    printf '%s/v%s' "$BACKUP_ROOT" "$(normalize_version "$1")"
}

# A usable snapshot must include at least one schema-critical path.
snapshot_has_schema_content() {
    local root="$1"
    [ -e "${root}/openclaw.json" ] || [ -e "${root}/state" ] || [ -e "${root}/agents" ]
}

has_pre_update_state_backup() {
    local ver="$1" dest
    dest="$(backup_path_for "$ver")"
    [ -f "${dest}/.complete" ] && [ -d "${dest}/state-dir" ] \
        && snapshot_has_schema_content "${dest}/state-dir"
}

# Keep the newest N aside dirs; older ones are safe to drop after a verified restore.
prune_state_asides() {
    local keep="${1:-2}"
    local -a dirs=()
    local d i=0

    while IFS= read -r d; do
        [ -n "$d" ] || continue
        dirs+=("$d")
    done < <(ls -1d "${OPENCLAW_HOME}/.openclaw.aside-"* 2>/dev/null | sort -r)

    for d in "${dirs[@]}"; do
        i=$((i + 1))
        if [ "$i" -gt "$keep" ]; then
            echo "Removing old state aside (keeping ${keep} newest): ${d}"
            rm -rf "$d"
        fi
    done
}

# Snapshot schema-critical state while the gateway is stopped (no live WAL writers).
# Refuses to mark .complete when nothing schema-critical was copied.
create_pre_update_state_backup() {
    local ver="$1"
    local dest item copied=0
    dest="$(backup_path_for "$ver")"

    echo "Saving pre-update state snapshot for v${ver} (required for safe rollback)..."
    rm -rf "$dest"
    mkdir -p "${dest}/state-dir"

    if [ ! -d "$STATE_DIR" ]; then
        echo "❌ Error: ${STATE_DIR} missing; cannot create a rollback snapshot." >&2
        rm -rf "$dest"
        return 1
    fi

    for item in "${STATE_BACKUP_ITEMS[@]}"; do
        if [ -e "${STATE_DIR}/${item}" ]; then
            cp -a "${STATE_DIR}/${item}" "${dest}/state-dir/"
            copied=1
        fi
    done

    if [ "$copied" -ne 1 ] || ! snapshot_has_schema_content "${dest}/state-dir"; then
        echo "❌ Error: snapshot for v${ver} has no openclaw.json/state/agents; refusing empty backup." >&2
        rm -rf "$dest"
        return 1
    fi

    printf '%s\n' "$ver" >"${dest}/VERSION"
    date -u +%Y-%m-%dT%H:%M:%SZ >"${dest}/CREATED_AT"
    touch "${dest}/.complete"
    set_env_kv OPENCLAW_STATE_BACKUP "$dest"
    echo "State snapshot saved: ${dest}"
}

# Replace live schema-critical paths with the snapshot for $ver. Current live
# copies are moved aside (not deleted) for forensics; older asides are pruned.
restore_pre_update_state_backup() {
    local ver="$1"
    local src aside item ts
    src="$(backup_path_for "$ver")"

    if ! has_pre_update_state_backup "$ver"; then
        echo "❌ Error: no usable pre-update state snapshot for v${ver} at ${src}" >&2
        return 1
    fi

    ts="$(date -u +%Y%m%dT%H:%M:%SZ)"
    aside="${STATE_DIR}.aside-${ts}"
    mkdir -p "$aside" "$STATE_DIR"

    echo "Restoring pre-update state for v${ver} from ${src}..."
    echo "  (current schema-critical paths moved to ${aside})"

    for item in "${STATE_BACKUP_ITEMS[@]}"; do
        if [ -e "${STATE_DIR}/${item}" ]; then
            mv "${STATE_DIR}/${item}" "${aside}/"
        fi
    done

    for item in "${STATE_BACKUP_ITEMS[@]}"; do
        if [ -e "${src}/state-dir/${item}" ]; then
            cp -a "${src}/state-dir/${item}" "${STATE_DIR}/"
        fi
    done

    if ! snapshot_has_schema_content "$STATE_DIR"; then
        echo "❌ Error: restore of v${ver} did not produce schema-critical state; not pruning asides." >&2
        return 1
    fi

    chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "$STATE_DIR"
    chmod 0700 "$STATE_DIR" 2>/dev/null || true
    [ -f "${STATE_DIR}/openclaw.json" ] && chmod 0600 "${STATE_DIR}/openclaw.json" || true
    prune_state_asides 2
    echo "State restore completed for v${ver}."
    echo "  Aside kept at ${aside} (older asides pruned; remove manually when verified)."
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

# True if any openclaw gateway / node gateway writer is still alive for the
# service user (doctor needs exclusive SQLite access).
gateway_writers_still_running() {
    pgrep -u "$OPENCLAW_USER" -f 'openclaw gateway' >/dev/null 2>&1 \
        || pgrep -u "$OPENCLAW_USER" -f 'openclaw/.*/dist/index.js gateway' >/dev/null 2>&1 \
        || pgrep -u "$OPENCLAW_USER" -f 'node .*gateway --port' >/dev/null 2>&1
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

install_openclaw_package() {
    local ver="$1"
    echo "Installing openclaw@${ver} from npm..."
    npm install -g "openclaw@${ver}"
}

# After a failed post-upgrade doctor, restore prior package + state snapshot.
rollback_after_doctor_failure() {
    local prior="$1"
    local failed="$2"

    echo "❌ Error: openclaw doctor --fix failed after installing openclaw@${failed}." >&2
    echo "   Schema migrations / repair did not finish (see doctor output above)." >&2
    echo "   Docs: https://docs.openclaw.ai/reference/database-schemas" >&2

    if [ -z "${prior}" ] || [ "${prior}" = "latest" ] || [ "${prior}" = "${failed}" ]; then
        echo "   No prior pin to restore. Gateway left stopped. Retry:" >&2
        echo "     sudo systemctl stop openclaw" >&2
        echo "     sudo -u openclaw -H env HOME=/home/openclaw OPENCLAW_SERVICE_REPAIR_POLICY=external \\" >&2
        echo "       openclaw doctor --fix --yes --non-interactive" >&2
        echo "     sudo systemctl start openclaw" >&2
        return 1
    fi

    echo "Restoring previous package openclaw@${prior} and pre-update state..." >&2

    # Fail closed: package-only rollback leaves a newer schema under an older
    # binary (doctor/gateway refuse). Prefer a stopped droplet over a mismatch.
    if ! has_pre_update_state_backup "$prior"; then
        echo "❌ Error: no usable state snapshot for v${prior}; refusing package-only rollback." >&2
        echo "   Gateway left stopped to avoid newer-schema / older-package mismatch." >&2
        echo "   Manual: restore a verified backup, then sudo /opt/update-openclaw.sh v${prior}" >&2
        echo "   Or repair on the new build:" >&2
        echo "     sudo -u openclaw -H env HOME=/home/openclaw OPENCLAW_SERVICE_REPAIR_POLICY=external \\" >&2
        echo "       openclaw doctor --fix --yes --non-interactive" >&2
        return 1
    fi
    if ! restore_pre_update_state_backup "$prior"; then
        echo "❌ Error: failed to restore state snapshot for v${prior}; gateway left stopped." >&2
        return 1
    fi

    if ! install_openclaw_package "$prior"; then
        echo "❌ Error: rollback install of openclaw@${prior} failed; gateway left stopped." >&2
        echo "   Manual: sudo /opt/update-openclaw.sh --rollback" >&2
        return 1
    fi

    set_env_kv OPENCLAW_VERSION "v${prior}"
    if systemctl start openclaw; then
        echo "⚠️  Rolled back to v${prior} (package + state) and restarted. Fix doctor issues before updating again." >&2
        echo "   Retry update later: sudo /opt/update-openclaw.sh" >&2
    else
        echo "❌ Error: rolled back package+state to v${prior} but failed to start openclaw." >&2
        echo "   Check: journalctl -u openclaw -xe" >&2
    fi
    return 1
}

refuse_downgrade_without_backup() {
    local current="$1"
    local target="$2"

    echo "❌ Error: cannot downgrade openclaw@${current} → @${target}." >&2
    echo "   OpenClaw database schemas are forward-only. After ${current} migrated" >&2
    echo "   state, ${target} refuses the newer schema (doctor cannot repair it)." >&2
    echo "   No pre-update state snapshot found at $(backup_path_for "$target")." >&2
    echo >&2
    echo "   Options:" >&2
    echo "     • Stay on v${current} (recommended if the upgrade already succeeded)." >&2
    echo "     • Restore a verified backup taken before the upgrade, then:" >&2
    echo "         sudo /opt/update-openclaw.sh v${target}" >&2
    echo "     • See: https://docs.openclaw.ai/install/updating/rollback-and-recovery" >&2
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

# Resolve whether this change is a downgrade (needs matching state snapshot).
DOING_DOWNGRADE=0
if [ "$MODE" = "rollback" ]; then
    DOING_DOWNGRADE=1
elif [ -n "${BEFORE_VERSION}" ] && is_version_downgrade "$BEFORE_VERSION" "$TARGET"; then
    DOING_DOWNGRADE=1
fi

if [ "$DOING_DOWNGRADE" -eq 1 ]; then
    if ! has_pre_update_state_backup "$TARGET"; then
        refuse_downgrade_without_backup "${BEFORE_VERSION:-unknown}" "$TARGET"
        # Do not stop / replace package when we already know it will fail.
        if ! systemctl is-active --quiet openclaw 2>/dev/null; then
            systemctl start openclaw || true
        fi
        exit 1
    fi
fi

stop_openclaw_for_maintenance

if [ "$DOING_DOWNGRADE" -eq 1 ]; then
    # Keep a snapshot of the newer state so a later re-upgrade can recover
    # post-upgrade data if needed (best-effort; downgrade still needs TARGET backup).
    if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "latest" ] \
        && [ "${BEFORE_VERSION}" != "${TARGET}" ]; then
        create_pre_update_state_backup "$BEFORE_VERSION" \
            || echo "⚠️  Warning: could not snapshot current v${BEFORE_VERSION} before downgrade (continuing)." >&2
    fi
    # Restore pre-upgrade schema before activating the older package.
    if ! restore_pre_update_state_backup "$TARGET"; then
        echo "❌ Error: state restore for v${TARGET} failed; gateway left stopped." >&2
        exit 1
    fi
elif [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "latest" ] \
    && { [ "${TARGET}" = "latest" ] || [ "${BEFORE_VERSION}" != "${TARGET}" ]; }; then
    # Upgrade (or update to latest): snapshot current state for future rollback.
    if ! create_pre_update_state_backup "$BEFORE_VERSION"; then
        echo "❌ Error: could not snapshot state for rollback; aborting update." >&2
        systemctl start openclaw || true
        exit 1
    fi
fi

if install_openclaw_package "$TARGET"; then
    echo "OpenClaw package install succeeded."

    INSTALLED_VERSION="$(npm list -g openclaw --depth=0 2>/dev/null | grep openclaw@ | sed 's/.*openclaw@//' | sed 's/ .*//' || true)"
    if [ -z "${INSTALLED_VERSION}" ]; then
        echo "❌ Error: openclaw installed but version could not be detected" >&2
        systemctl start openclaw || true
        exit 1
    fi

    # If "latest" resolved to the same pin, no previous-pin bookkeeping needed.
    # Save previous pin only when the installed version actually changes.
    if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "latest" ] \
        && [ "${BEFORE_VERSION}" != "${INSTALLED_VERSION}" ]; then
        set_env_kv OPENCLAW_VERSION_PREVIOUS "v${BEFORE_VERSION}"
        echo "Saved previous version for rollback: v${BEFORE_VERSION}"
        if has_pre_update_state_backup "$BEFORE_VERSION"; then
            set_env_kv OPENCLAW_STATE_BACKUP "$(backup_path_for "$BEFORE_VERSION")"
        fi
    fi
    set_env_kv OPENCLAW_VERSION "v${INSTALLED_VERSION}"

    # Re-assert stop after npm (and before doctor): writers must be down for
    # agent schema migrations (v19+ session-identity / creator-namespace).
    stop_openclaw_for_maintenance

    echo "Running post-upgrade doctor (gateway stopped)..."
    if run_openclaw_doctor_fix; then
        echo "Doctor repair completed."
    else
        if [ "$DOING_DOWNGRADE" -eq 1 ]; then
            echo "❌ Error: doctor failed after restoring v${INSTALLED_VERSION} state + package." >&2
            echo "   Gateway left stopped. Inspect doctor output and:" >&2
            echo "     sudo -u openclaw -H env HOME=/home/openclaw OPENCLAW_SERVICE_REPAIR_POLICY=external \\" >&2
            echo "       openclaw doctor --fix --yes --non-interactive" >&2
            exit 1
        fi
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
        if [ "$MODE" = "rollback" ] || [ "$DOING_DOWNGRADE" -eq 1 ]; then
            echo "✅ OpenClaw rolled back and restarted successfully!"
            echo "   Pre-update state snapshot was restored (post-upgrade data discarded)."
        else
            echo "✅ OpenClaw updated and restarted successfully!"
        fi
        echo "Version: ${INSTALLED_VERSION}"
        if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "${INSTALLED_VERSION}" ] \
            && [ "$DOING_DOWNGRADE" -eq 0 ]; then
            echo "Rollback (if needed): sudo /opt/update-openclaw.sh --rollback"
            if has_pre_update_state_backup "$BEFORE_VERSION"; then
                echo "  (restores package + state snapshot at $(backup_path_for "$BEFORE_VERSION"))"
            fi
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
