#!/bin/bash
# Update @openhands/agent-canvas from npm and restart the service.
#
# Usage:
#   /opt/update-openhands.sh              # install latest from npm
#   /opt/update-openhands.sh latest       # same as no args
#   /opt/update-openhands.sh 1.16.0       # install that exact version
#   /opt/update-openhands.sh --list       # print recent versions and exit
#   /opt/update-openhands.sh --rollback   # reinstall OPENHANDS_VERSION_PREVIOUS
#
# Agent Canvas 1.17+ requires Node >=24. This 1-Click originally shipped Node 22,
# so installing "latest" without a Node upgrade fails. The helper upgrades Node
# via the NodeSource 24.x apt repo when the chosen version needs it.

set -euo pipefail

ENV_FILE=/opt/openhands.env
NPM_PKG="@openhands/agent-canvas"
NPM_REGISTRY="https://registry.npmjs.org/@openhands%2fagent-canvas"
LIST_COUNT=10

PACKUMENT=""

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 ${*:-}" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: /opt/update-openhands.sh [version|--list|--rollback]

  (no args) / latest   Install the latest Agent Canvas release from npm
  1.16.0               Install that exact Agent Canvas version
  --list               Print current, latest, and recent versions, then exit
  --rollback           Reinstall OPENHANDS_VERSION_PREVIOUS from /opt/openhands.env

Agent Canvas 1.17+ needs Node >=24. If this droplet still has Node 22, the
helper upgrades Node to 24.x before installing those versions.
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
  from_env="$(read_env_kv OPENHANDS_VERSION || true)"
  if [ -n "${from_env}" ]; then
    normalize_version "$from_env"
    return 0
  fi
  from_npm="$(npm_installed_version || true)"
  if [ -n "${from_npm}" ]; then
    printf '%s' "$from_npm"
    return 0
  fi
  return 1
}

npm_installed_version() {
  npm list -g "$NPM_PKG" --depth=0 --json 2>/dev/null \
    | jq -r --arg pkg "$NPM_PKG" '.dependencies[$pkg].version // empty' \
    || true
}

fetch_packument() {
  if [ -n "$PACKUMENT" ]; then
    return 0
  fi
  if ! PACKUMENT=$(curl -fsS "$NPM_REGISTRY"); then
    PACKUMENT=""
    return 1
  fi
}

latest_from_npm() {
  fetch_packument
  printf '%s' "$PACKUMENT" | jq -r '.["dist-tags"].latest // empty'
}

version_exists() {
  local ver="$1"
  fetch_packument || return 1
  printf '%s' "$PACKUMENT" | jq -e --arg v "$ver" '.versions[$v] != null' >/dev/null
}

version_node_engine() {
  local ver="$1"
  fetch_packument || { printf '%s' ""; return 0; }
  printf '%s' "$PACKUMENT" | jq -r --arg v "$ver" '.versions[$v].engines.node // empty'
}

stable_versions() {
  fetch_packument
  printf '%s' "$PACKUMENT" | jq -r '
    .versions | keys[]
    | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
  ' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n "$LIST_COUNT" \
    | awk '{ a[NR] = $0 } END { for (i = NR; i >= 1; i--) print a[i] }'
}

# Floor-only: Agent Canvas currently publishes engines.node as ">=X" or
# ">=X.Y.Z". A future range with an upper bound would be ignored here.
node_meets_engines() {
  local req="$1"
  [ -z "$req" ] && return 0
  command -v node >/dev/null 2>&1 || return 1
  node -e '
    const req = process.argv[1].trim();
    const m = req.match(/>=\s*(\d+)(?:\.(\d+))?(?:\.(\d+))?/);
    if (!m) process.exit(0);
    const need = [Number(m[1]), Number(m[2] || 0), Number(m[3] || 0)];
    const have = process.versions.node.split(".").map(Number);
    for (let i = 0; i < 3; i++) {
      if ((have[i] || 0) > need[i]) process.exit(0);
      if ((have[i] || 0) < need[i]) process.exit(1);
    }
    process.exit(0);
  ' "$req"
}

install_node_24() {
  echo "Installing Node.js 24.x from NodeSource (signed apt repo)..."
  mkdir -p /etc/apt/keyrings
  tmp_key=$(mktemp)
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor >"$tmp_key"
  install -m 0644 "$tmp_key" /etc/apt/keyrings/nodesource.gpg
  rm -f "$tmp_key"
  # Replace any Node 22 NodeSource entries from the original image install.
  # setup_22.x writes the deb822 nodesource.sources; older setups wrote
  # nodesource.list. Remove both so only the 24.x entry below is left.
  rm -f /etc/apt/sources.list.d/nodesource.list \
        /etc/apt/sources.list.d/nodesource.sources
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
}

ensure_node_for_version() {
  local ver="$1"
  local req current
  req="$(version_node_engine "$ver")"
  if node_meets_engines "$req"; then
    echo "Node $(node --version) meets Agent Canvas ${ver} requirements${req:+ ($req)}."
    return 0
  fi

  current="$(node --version 2>/dev/null || echo missing)"
  echo "Agent Canvas ${ver} requires Node ${req:-unknown} (found ${current})."
  install_node_24

  if ! node_meets_engines "$req"; then
    echo "Error: Node still too old after upgrade ($(node --version 2>/dev/null || echo missing))" >&2
    exit 1
  fi
  echo "Node upgraded to $(node --version)."
}

print_version_row() {
  local ver="$1" current="$2" latest="$3"
  local mark="" engine
  [ "$ver" = "$latest" ] && mark="${mark} latest"
  [ "$ver" = "$current" ] && mark="${mark} current"
  engine="$(version_node_engine "$ver")"
  printf "  %-10s" "$ver"
  [ -n "$mark" ] && printf " (%s)" "${mark# }"
  [ -n "$engine" ] && printf "  [Node %s]" "$engine"
  echo
}

print_version_list() {
  local current="$1" latest="$2"
  local ver
  echo "Currently installed: ${current:-unknown}"
  echo "Latest on npm:       ${latest:-unknown}"
  echo "Node:                $(node --version 2>/dev/null || echo missing)"
  echo
  echo "Recent stable Agent Canvas versions:"
  while IFS= read -r ver; do
    [ -n "$ver" ] || continue
    print_version_row "$ver" "$current" "$latest"
  done < <(stable_versions)
}

resolve_target() {
  local target="$1" latest
  if [ "$target" = "latest" ]; then
    latest="$(latest_from_npm)"
    if [ -z "$latest" ] || [ "$latest" = "null" ]; then
      echo "Error: could not determine latest version from npm" >&2
      exit 1
    fi
    printf '%s' "$latest"
    return 0
  fi
  printf '%s' "$target"
}

install_agent_canvas() {
  local target="$1"
  echo "Installing ${NPM_PKG}@${target} from npm..."
  npm install -g "${NPM_PKG}@${target}"
}

# systemd ExecStart is /usr/local/bin/agent-canvas. Never use `command -v` and
# never `ln -sfn` that path onto itself: PATH prefers /usr/local/bin, so the
# link becomes circular and the unit dies with 203/EXEC
# ("Too many levels of symbolic links").
is_circular_link() {
  local p="$1" target
  [ -L "$p" ] || return 1
  target="$(readlink "$p" || true)"
  [ "$target" = "$p" ] || [ "$target" = "$(basename "$p")" ] || [ "$target" = "./$(basename "$p")" ]
}

npm_agent_canvas_bin() {
  local prefix bin mjs
  prefix="$(npm prefix -g 2>/dev/null || true)"
  [ -n "$prefix" ] || prefix="/usr"
  bin="${prefix}/bin/agent-canvas"
  mjs="${prefix}/lib/node_modules/@openhands/agent-canvas/bin/agent-canvas.mjs"

  # Prefer the real package file, not a shim that might already be dest.
  if [ -e "$mjs" ]; then
    printf '%s' "$mjs"
    return 0
  fi
  if [ -e /usr/bin/agent-canvas ] && [ /usr/bin/agent-canvas != /usr/local/bin/agent-canvas ]; then
    printf '%s' "/usr/bin/agent-canvas"
    return 0
  fi
  if [ -e "$bin" ] && [ "$bin" != "/usr/local/bin/agent-canvas" ]; then
    printf '%s' "$bin"
    return 0
  fi
  return 1
}

relink_canvas_bin() {
  local dest="/usr/local/bin/agent-canvas"
  local canvas_bin resolved

  if is_circular_link "$dest"; then
    echo "Removing circular symlink ${dest}"
    rm -f "$dest"
  fi

  canvas_bin="$(npm_agent_canvas_bin || true)"
  if [ -z "$canvas_bin" ] || [ ! -e "$canvas_bin" ]; then
    echo "Error: agent-canvas binary not found after npm install" >&2
    return 1
  fi
  if [ "$canvas_bin" = "$dest" ]; then
    echo "Error: refusing to symlink ${dest} onto itself" >&2
    return 1
  fi

  ln -sfn "$canvas_bin" "$dest"
  resolved="$(readlink -f "$dest" 2>/dev/null || true)"
  if [ -z "$resolved" ] || [ ! -e "$resolved" ]; then
    echo "Error: ${dest} does not resolve after relink (got '${resolved}')" >&2
    return 1
  fi
  echo "Linked ${dest} -> ${resolved}"
}

port_in_use() {
  local port="$1"
  ss -ltn 2>/dev/null | grep -qE ":${port}[[:space:]]" || return 1
}

stop_openhands() {
  echo "Stopping OpenHands service..."
  systemctl stop openhands || true

  local i
  for i in $(seq 1 15); do
    if ! systemctl is-active --quiet openhands; then
      break
    fi
    sleep 1
  done

  # uvx agent-server / automation can keep :8000/:18000 after the unit stops.
  if pgrep -u openhands -f 'agent-canvas|openhands-agent-server|agent-server' >/dev/null 2>&1; then
    echo "Stopping leftover OpenHands processes..."
    pkill -u openhands -f 'agent-canvas|openhands-agent-server|agent-server' || true
    sleep 1
  fi

  for i in $(seq 1 15); do
    if ! port_in_use 8000 && ! port_in_use 18000; then
      return 0
    fi
    sleep 1
  done
  echo "Warning: port 8000 or 18000 still in use after stop." >&2
}

dump_openhands_failure() {
  echo "----- agent-canvas binary -----" >&2
  ls -l /usr/local/bin/agent-canvas /usr/bin/agent-canvas 2>&1 || true
  echo "----- run as service user -----" >&2
  runuser -u openhands -- /usr/local/bin/agent-canvas --version 2>&1 || true
  echo "----- systemctl status -----" >&2
  systemctl status openhands --no-pager -l 2>&1 || true
  echo "----- journalctl -u openhands -n 80 -----" >&2
  journalctl -u openhands -n 80 --no-pager 2>&1 || true
}

wait_until_active() {
  local i
  # RestartSec=5, and a new Agent Canvas may spend several seconds on uvx.
  for i in $(seq 1 15); do
    if systemctl is-active --quiet openhands; then
      return 0
    fi
    sleep 2
  done
  return 1
}

MODE="update"
TARGET=""
BEFORE_VERSION="$(current_installed_version || true)"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --list|-l)
    if ! fetch_packument; then
      echo "Error: could not fetch versions from npm" >&2
      exit 1
    fi
    print_version_list "${BEFORE_VERSION:-unknown}" "$(latest_from_npm)"
    exit 0
    ;;
  --rollback|-r)
    MODE="rollback"
    PREV="$(read_env_kv OPENHANDS_VERSION_PREVIOUS || true)"
    if [ -z "${PREV}" ]; then
      echo "Error: OPENHANDS_VERSION_PREVIOUS is not set in ${ENV_FILE}." >&2
      echo "Cannot rollback. Install a specific version instead, e.g.:" >&2
      echo "  sudo /opt/update-openhands.sh 1.16.0" >&2
      exit 1
    fi
    TARGET="$(normalize_version "$PREV")"
    ;;
  *)
    TARGET="$(normalize_version "${1:-latest}")"
    ;;
esac

TARGET="$(resolve_target "$TARGET")"

if ! version_exists "$TARGET"; then
  echo "Error: ${NPM_PKG}@${TARGET} was not found on npm" >&2
  echo "List available versions with: sudo /opt/update-openhands.sh --list" >&2
  exit 1
fi

if [ "$MODE" = "rollback" ]; then
  echo "Rolling back OpenHands Agent Canvas to ${TARGET}..."
else
  echo "Updating OpenHands Agent Canvas (target: ${TARGET})..."
fi
if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "latest" ]; then
  echo "Currently installed: ${BEFORE_VERSION}"
fi

ensure_node_for_version "$TARGET"

stop_openhands

if install_agent_canvas "$TARGET"; then
  if ! relink_canvas_bin; then
    echo "Error: failed to relink agent-canvas after install" >&2
    systemctl start openhands || true
    exit 1
  fi

  INSTALLED_VERSION="$(npm_installed_version || true)"
  if [ -z "${INSTALLED_VERSION}" ]; then
    echo "Error: package installed but version could not be detected" >&2
    systemctl start openhands || true
    exit 1
  fi

  if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "latest" ] \
    && [ "${BEFORE_VERSION}" != "${INSTALLED_VERSION}" ]; then
    set_env_kv OPENHANDS_VERSION_PREVIOUS "${BEFORE_VERSION}"
    echo "Saved previous version for rollback: ${BEFORE_VERSION}"
  fi
  set_env_kv OPENHANDS_VERSION "${INSTALLED_VERSION}"

  echo "Starting OpenHands..."
  if systemctl start openhands; then
    if wait_until_active; then
      if [ "$MODE" = "rollback" ]; then
        echo "OpenHands rolled back and restarted successfully."
      else
        echo "OpenHands updated and restarted successfully."
      fi
      echo "Version: ${INSTALLED_VERSION}"
      if [ -n "${BEFORE_VERSION}" ] && [ "${BEFORE_VERSION}" != "${INSTALLED_VERSION}" ]; then
        echo "Rollback (if needed): sudo /opt/update-openhands.sh --rollback"
      fi
    else
      echo "Update installed but service failed to start." >&2
      dump_openhands_failure
      exit 1
    fi
  else
    echo "Error: failed to restart OpenHands" >&2
    dump_openhands_failure
    exit 1
  fi
else
  echo "Error: failed to install ${NPM_PKG}@${TARGET}" >&2
  systemctl start openhands || true
  exit 1
fi
