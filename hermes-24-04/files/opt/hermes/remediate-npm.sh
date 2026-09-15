#!/bin/bash
# Clear high/critical npm advisories that hermes doctor reports for the
# browser-tools / web / ui-tui workspaces. Safe to re-run; best-effort.
#
# Hermes ships engine-strict + min-release-age in .npmrc, which can block
# `npm audit fix` from applying published security bumps. Temporarily relax
# those gates for remediation only (same approach as upstream doctor issues).

set -euo pipefail

HERMES_USER=${HERMES_USER:-hermes}
HERMES_AGENT_DIR=${HERMES_AGENT_DIR:-/home/hermes/.hermes/hermes-agent}

if [ ! -d "$HERMES_AGENT_DIR" ]; then
    echo "Hermes agent checkout not found at $HERMES_AGENT_DIR" >&2
    exit 0
fi

echo "Remediating Hermes npm advisories in $HERMES_AGENT_DIR..."

tmp="$(mktemp)"
cat >"$tmp" <<'EOF'
#!/bin/bash
set -euo pipefail

if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found on PATH; skipping."
  exit 0
fi

cd "$HERMES_AGENT_DIR"

# Relax install gates for security bumps only.
export NPM_CONFIG_ENGINE_STRICT=false
export npm_config_engine_strict=false
export npm_config_min_release_age=0

run_fix() {
  npm audit fix "$@" >/dev/null 2>&1 || true
}

args=()
if [ -f ui-tui/package.json ] || [ -f web/package.json ]; then
  [ -f ui-tui/package.json ] && args+=(--workspace ui-tui)
  [ -f web/package.json ] && args+=(--workspace web)
  args+=(--include-workspace-root)
  run_fix "${args[@]}"
fi

run_fix --workspaces=false

if [ -d ui-tui ]; then
  (cd ui-tui && run_fix)
fi
if [ -d web ]; then
  (cd web && run_fix)
fi
EOF
chmod 0755 "$tmp"

if [ "$(id -un)" = "$HERMES_USER" ]; then
    HERMES_AGENT_DIR="$HERMES_AGENT_DIR" bash "$tmp" || true
elif [ "$(id -u)" -eq 0 ]; then
    su - "$HERMES_USER" -c "HERMES_AGENT_DIR=$(printf '%q' "$HERMES_AGENT_DIR") bash $tmp" || true
else
    HERMES_AGENT_DIR="$HERMES_AGENT_DIR" bash "$tmp" || true
fi

rm -f "$tmp"
echo "Hermes npm remediation finished."
