#!/bin/bash
# Update OpenHands Agent Canvas to the latest npm release and restart the service.
#
# Usage:
#   sudo /opt/update-openhands.sh
#
# Same pattern as ZeroClaw / OpenCode: latest only (no pin / list / rollback).
# Agent Canvas config and workspace data are forward-migrating; this helper only
# replaces the npm package.
#
# Ensures Node.js meets NODE_MIN_VERSION from /opt/openhands.env (CVE floor;
# default 24.22.1) before installing. Older droplets on Node 22 are upgraded
# via the NodeSource 24.x apt repo.

set -euo pipefail

ENV_FILE=/opt/openhands.env
NPM_PKG="@openhands/agent-canvas"
NODE_MIN_VERSION_DEFAULT="24.22.1"
NODE_MIN_VERSION=""
NODE_DEB_MIN_VERSION=""

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

if [ "$#" -gt 0 ]; then
  cat <<'EOF' >&2
Usage: sudo /opt/update-openhands.sh

Installs the latest @openhands/agent-canvas from npm and restarts OpenHands.
Version pins, --list, and --rollback are not supported.
EOF
  exit 1
fi

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

npm_installed_version() {
  npm list -g "$NPM_PKG" --depth=0 --json 2>/dev/null \
    | jq -r --arg pkg "$NPM_PKG" '.dependencies[$pkg].version // empty' \
    || true
}

normalize_node_semver() {
  printf '%s' "$1" | sed -E -n 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'
}

load_node_min_version() {
  local from_env raw norm
  from_env="$(read_env_kv NODE_MIN_VERSION || true)"
  if [ -z "$from_env" ]; then
    from_env="$(read_env_kv NODE_CVE_FLOOR || true)"
  fi
  raw="${from_env:-$NODE_MIN_VERSION_DEFAULT}"
  norm="$(normalize_node_semver "$raw")"
  if [ -z "$norm" ]; then
    echo "Error: invalid NODE_MIN_VERSION '${raw}' (want X.Y.Z or X.Y.Z+)" >&2
    NODE_MIN_VERSION=""
    NODE_DEB_MIN_VERSION=""
    return 1
  fi
  NODE_MIN_VERSION="$norm"
  NODE_DEB_MIN_VERSION="${NODE_MIN_VERSION}-1nodesource1"
}

node_meets_min_version() {
  load_node_min_version || return 1
  command -v node >/dev/null 2>&1 || return 1
  node -e '
    const parse = (s) => {
      const m = String(s).trim().match(/^v?(\d+)\.(\d+)\.(\d+)/);
      if (!m) process.exit(1);
      return [Number(m[1]), Number(m[2]), Number(m[3])];
    };
    const need = parse(process.argv[1]);
    const have = parse(process.versions.node);
    for (let i = 0; i < 3; i++) {
      if (have[i] > need[i]) process.exit(0);
      if (have[i] < need[i]) process.exit(1);
    }
    process.exit(0);
  ' "$NODE_MIN_VERSION"
}

restore_nodesource_apt_backup() {
  local backup_dir="$1" prefs_path="$2" f
  rm -f /etc/apt/sources.list.d/nodesource.list \
        /etc/apt/sources.list.d/nodesource.sources \
        "$prefs_path"
  for f in nodesource.list nodesource.sources; do
    if [ -e "${backup_dir}/$f" ]; then
      cp -a "${backup_dir}/$f" "/etc/apt/sources.list.d/$f"
    fi
  done
  if [ -e "${backup_dir}/nodesource-nodejs.pref" ]; then
    cp -a "${backup_dir}/nodesource-nodejs.pref" "$prefs_path"
  fi
  apt-get update -y >/dev/null 2>&1 || true
}

install_node_24() {
  local tmp_key backup_dir f rc=0 package_installed=0
  local prefs_path=/etc/apt/preferences.d/nodesource-nodejs
  local prev_nodejs_ver=""
  load_node_min_version || return 1
  echo "Installing Node.js ${NODE_MIN_VERSION}+ from NodeSource (signed apt repo)..."
  mkdir -p /etc/apt/keyrings

  prev_nodejs_ver="$(dpkg-query -W -f='${Version}' nodejs 2>/dev/null || true)"

  tmp_key="$(mktemp)"
  if ! curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor >"$tmp_key"; then
    rm -f "$tmp_key"
    echo "Error: could not fetch the NodeSource signing key" >&2
    return 1
  fi
  if ! install -m 0644 "$tmp_key" /etc/apt/keyrings/nodesource.gpg; then
    rm -f "$tmp_key"
    echo "Error: could not install the NodeSource keyring" >&2
    return 1
  fi
  rm -f "$tmp_key"

  backup_dir="$(mktemp -d)"
  if [ -z "$backup_dir" ] || [ ! -d "$backup_dir" ]; then
    echo "Error: could not create a temp dir for the apt source backup" >&2
    return 1
  fi
  for f in nodesource.list nodesource.sources; do
    if [ -e "/etc/apt/sources.list.d/$f" ]; then
      cp -a "/etc/apt/sources.list.d/$f" "${backup_dir}/$f"
    fi
  done
  if [ -e "$prefs_path" ]; then
    cp -a "$prefs_path" "${backup_dir}/nodesource-nodejs.pref"
  fi
  rm -f /etc/apt/sources.list.d/nodesource.list \
        /etc/apt/sources.list.d/nodesource.sources

  cat > "$prefs_path" <<EOF
Package: nodejs
Pin: origin deb.nodesource.com
Pin-Priority: 1001
EOF

  if ! printf '%s\n' \
    "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list; then
    echo "Error: could not write the NodeSource 24.x apt entry" >&2
    rc=1
  elif ! apt-get update -y; then
    rc=1
  else
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "nodejs=${NODE_DEB_MIN_VERSION}" \
      || DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs; then
      package_installed=1
      if ! node_meets_min_version; then
        echo "Error: Node $(node --version 2>/dev/null || echo missing) is below minimum ${NODE_MIN_VERSION}" >&2
        rc=1
      fi
    else
      rc=1
    fi
  fi

  if [ "$rc" -ne 0 ]; then
    if [ "$package_installed" -eq 0 ]; then
      echo "Error: Node.js 24 install failed; restoring the previous apt sources" >&2
    else
      echo "Error: Node.js was installed but is below minimum ${NODE_MIN_VERSION}; restoring previous Node and apt sources" >&2
    fi
    restore_nodesource_apt_backup "$backup_dir" "$prefs_path"
    if [ "$package_installed" -eq 1 ] && [ -n "$prev_nodejs_ver" ]; then
      if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades \
        "nodejs=${prev_nodejs_ver}"; then
        echo "Warning: could not restore nodejs=${prev_nodejs_ver}; check node --version before restarting OpenHands" >&2
      else
        echo "Restored nodejs ${prev_nodejs_ver}."
      fi
    elif [ "$package_installed" -eq 1 ]; then
      echo "Warning: no previous nodejs package version to restore; check node --version before restarting OpenHands" >&2
    fi
  fi
  rm -rf "$backup_dir"
  return "$rc"
}

ensure_node() {
  local current
  load_node_min_version || exit 1
  if node_meets_min_version; then
    echo "Node $(node --version) meets minimum ${NODE_MIN_VERSION}."
    return 0
  fi

  current="$(node --version 2>/dev/null || echo missing)"
  echo "Node ${current} is below minimum ${NODE_MIN_VERSION}; upgrading."
  if ! install_node_24; then
    echo "Error: could not bring Node to >= ${NODE_MIN_VERSION}; Agent Canvas was not updated." >&2
    exit 1
  fi
  if ! node_meets_min_version; then
    echo "Error: Node still below minimum ${NODE_MIN_VERSION} ($(node --version 2>/dev/null || echo missing))" >&2
    exit 1
  fi
  echo "Node upgraded to $(node --version)."
}

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

  if ! ln -sfn "$canvas_bin" "$dest"; then
    echo "Error: could not link ${dest} -> ${canvas_bin}" >&2
    return 1
  fi
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

unit_restart_count() {
  systemctl show -p NRestarts --value openhands 2>/dev/null || echo 0
}

wait_until_active() {
  local i restarts_before
  for i in $(seq 1 15); do
    if systemctl is-active --quiet openhands; then
      break
    fi
    sleep 2
  done
  systemctl is-active --quiet openhands || return 1

  restarts_before="$(unit_restart_count)"
  for i in 1 2 3 4; do
    sleep 2
    systemctl is-active --quiet openhands || return 1
    [ "$(unit_restart_count)" = "$restarts_before" ] || return 1
  done
  return 0
}

restart_after_failure() {
  echo "Restarting OpenHands on the currently installed version..." >&2
  if systemctl start openhands && wait_until_active; then
    echo "OpenHands is running again." >&2
    return 0
  fi
  echo "Error: OpenHands did not come back up." >&2
  dump_openhands_failure
  return 1
}

BEFORE_VERSION="$(read_env_kv OPENHANDS_VERSION || true)"
if [ -z "${BEFORE_VERSION}" ]; then
  BEFORE_VERSION="$(npm_installed_version || true)"
fi

echo "Updating OpenHands Agent Canvas to the latest npm release..."
if [ -n "${BEFORE_VERSION}" ]; then
  echo "Currently installed: ${BEFORE_VERSION}"
fi

ensure_node
stop_openhands

echo "Installing ${NPM_PKG}@latest from npm..."
if ! npm install -g "${NPM_PKG}@latest"; then
  echo "Error: failed to install ${NPM_PKG}@latest" >&2
  restart_after_failure || true
  exit 1
fi

INSTALLED_VERSION="$(npm_installed_version || true)"
if [ -z "${INSTALLED_VERSION}" ]; then
  echo "Warning: npm did not report an installed version." >&2
  INSTALLED_VERSION="latest"
fi
set_env_kv OPENHANDS_VERSION "${INSTALLED_VERSION}"
# Drop legacy rollback bookkeeping if present on older droplets.
if grep -q '^OPENHANDS_VERSION_PREVIOUS=' "$ENV_FILE" 2>/dev/null; then
  sed -i '/^OPENHANDS_VERSION_PREVIOUS=/d' "$ENV_FILE"
fi

if ! relink_canvas_bin; then
  echo "Error: failed to relink agent-canvas after install" >&2
  restart_after_failure || true
  exit 1
fi

echo "Starting OpenHands..."
if systemctl start openhands && wait_until_active; then
  echo "OpenHands updated and restarted successfully."
  echo "Version: ${INSTALLED_VERSION}"
else
  echo "Update installed but service failed to start." >&2
  dump_openhands_failure
  exit 1
fi
