#!/bin/bash
# Keep Paperclip on /usr/bin/node >= 24.22.1.
#
# Image bake, first boot, update, and the systemd unit all call this before
# paperclipai runs. A newer NodeSource 24.x package is installed when the
# system binary is missing or older. The managed shim is repinned to that
# binary so a later PATH entry cannot select an older Node.
set -euo pipefail

NODE_BIN=/usr/bin/node
NODE_FLOOR=24.22.1
SHIM=/home/paperclip/.local/bin/paperclipai
SHIM_MARKER="paperclipai managed install shim v1"

node_meets_floor() {
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
  ' "$NODE_FLOOR"
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
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
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

if ! node_meets_floor; then
  current="missing"
  if [ -x "$NODE_BIN" ]; then
    current="$("$NODE_BIN" --version 2>/dev/null || echo unknown)"
  fi
  echo "Node.js ${current} is below ${NODE_FLOOR}. Installing NodeSource node_24.x..."
  install_nodesource_node
fi

if ! node_meets_floor; then
  echo "ERROR: ${NODE_BIN} is $("$NODE_BIN" --version 2>/dev/null || echo missing); Paperclip requires Node.js ${NODE_FLOOR} or later." >&2
  exit 1
fi

pin_managed_shim
echo "Node $("$NODE_BIN" --version) meets the minimum (>=${NODE_FLOOR})."
