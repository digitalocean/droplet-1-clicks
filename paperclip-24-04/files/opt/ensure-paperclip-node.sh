#!/bin/bash
# Keep Paperclip on /usr/bin/node at the pinned Node.js version from the image
# build (node_version / NODE_VERSION), with a hard floor of 24.22.3.
#
# Image bake, first boot, update, and the systemd unit all call this before
# paperclipai runs. Prefers the exact NodeSource package, otherwise newest 24.x
# that still meets the floor. The managed shim is repinned to /usr/bin/node.
set -euo pipefail

NODE_BIN=/usr/bin/node
NODE_FLOOR=24.22.3
# Packer may pass node_version; runtime may set NODE_VERSION. Accept X.Y.Z or X.Y.Z+.
NODE_VERSION_RAW="${NODE_VERSION:-${node_version:-$NODE_FLOOR}}"
NODE_VERSION="$(printf '%s' "$NODE_VERSION_RAW" | sed -E -n 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
if [ -z "$NODE_VERSION" ]; then
  echo "ERROR: invalid NODE_VERSION/node_version '${NODE_VERSION_RAW}' (want X.Y.Z)" >&2
  exit 1
fi
NODE_DEB_VERSION="${NODE_VERSION}-1nodesource1"
SHIM=/home/paperclip/.local/bin/paperclipai
SHIM_MARKER="paperclipai managed install shim v1"

node_meets_version() {
  local need="$1"
  [ -x "$NODE_BIN" ] || return 1
  "$NODE_BIN" -e '
    function ge(a, b) {
      const pa = String(a).split(".").map((x) => parseInt(x, 10) || 0);
      const pb = String(b).split(".").map((x) => parseInt(x, 10) || 0);
      for (let i = 0; i < 3; i++) {
        if ((pa[i] || 0) > (pb[i] || 0)) return true;
        if ((pa[i] || 0) < (pb[i] || 0)) return false;
      }
      return true;
    }
    process.exit(ge(process.versions.node, process.argv[1]) ? 0 : 1);
  ' "$need"
}

configure_nodesource() {
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  chmod a+r /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  cat > /etc/apt/preferences.d/nodesource-nodejs <<'EOF'
Package: nodejs
Pin: origin deb.nodesource.com
Pin-Priority: 1001
EOF
}

install_nodesource_node() {
  configure_nodesource
  apt-get update -y
  if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "nodejs=${NODE_DEB_VERSION}"; then
    echo "Pinned nodejs=${NODE_DEB_VERSION} unavailable; installing newest NodeSource 24.x..." >&2
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  fi
}

pin_managed_shim() {
  [ -f "$SHIM" ] || return 0
  python3 - "$SHIM" "$NODE_BIN" "$SHIM_MARKER" <<'PY'
import pathlib, re, sys
path, node_bin, marker = sys.argv[1:]
file = pathlib.Path(path)
text = file.read_text(encoding="utf-8")
if marker not in text:
    sys.exit(0)
node_dir = str(pathlib.Path(node_bin).parent)
updated, execs = re.subn(
    r"^exec '[^']+' ",
    "exec '%s' " % node_bin,
    text,
    count=1,
    flags=re.M,
)
updated, paths = re.subn(
    r"^export PATH='[^']*':",
    "export PATH='%s':" % node_dir,
    updated,
    count=1,
    flags=re.M,
)
if execs != 1 or paths != 1:
    sys.stderr.write("Paperclip shim is not the managed Node launcher: %s\n" % path)
    sys.exit(1)
if updated != text:
    file.write_text(updated, encoding="utf-8")
    file.chmod(0o755)
PY
}

# Exact pin preferred; always enforce the security floor.
if ! node_meets_version "$NODE_VERSION"; then
  current="missing"
  if [ -x "$NODE_BIN" ]; then
    current="$("$NODE_BIN" --version 2>/dev/null || echo unknown)"
  fi
  echo "Node.js ${current} is below pin ${NODE_VERSION}. Installing NodeSource nodejs..."
  install_nodesource_node
fi

if ! node_meets_version "$NODE_FLOOR"; then
  echo "ERROR: ${NODE_BIN} is $("$NODE_BIN" --version 2>/dev/null || echo missing); Paperclip requires Node.js ${NODE_FLOOR} or later." >&2
  exit 1
fi

pin_managed_shim
echo "Node $("$NODE_BIN" --version) meets pin (>=${NODE_VERSION}; floor ${NODE_FLOOR})."
