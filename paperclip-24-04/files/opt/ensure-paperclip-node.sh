#!/bin/bash
# Keep Paperclip on /usr/bin/node at the pinned Node.js version from the image
# build (node_version / NODE_VERSION), with a hard floor of 24.22.3.
#
# Image bake, first boot, and update call this. Do NOT invoke from paperclip.service
# as root ExecStartPre (paperclip-writable EnvironmentFile / WorkingDirectory).
set -euo pipefail

# Ignore inherited env from a compromised caller (NODE_OPTIONS, BASH_ENV, PATH, …).
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unset BASH_ENV ENV NODE_OPTIONS NODE_PATH PYTHONPATH PYTHONHOME CDPATH
cd / || exit 1

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
  # Clear NODE_OPTIONS again for the child; use absolute interpreter.
  env -u NODE_OPTIONS -u NODE_PATH "$NODE_BIN" -e '
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
  [ -e "$SHIM" ] || [ -L "$SHIM" ] || return 0
  if [ -L "$SHIM" ]; then
    echo "ERROR: refusing to rewrite symlinked shim: $SHIM" >&2
    return 1
  fi
  if [ ! -f "$SHIM" ]; then
    echo "ERROR: shim is not a regular file: $SHIM" >&2
    return 1
  fi
  local nlink
  nlink="$(stat -c '%h' "$SHIM" 2>/dev/null || stat -f '%l' "$SHIM")"
  if [ "$nlink" != "1" ]; then
    echo "ERROR: refusing hardlinked shim: $SHIM" >&2
    return 1
  fi
  # -I: isolate mode (no PYTHONPATH / cwd on sys.path). Rewrite via temp + atomic mv.
  /usr/bin/python3 -I - "$SHIM" "$NODE_BIN" "$SHIM_MARKER" <<'PY'
import os, pathlib, re, sys, tempfile
path, node_bin, marker = sys.argv[1:]
file = pathlib.Path(path)
if file.is_symlink() or not file.is_file():
    sys.stderr.write("refusing non-regular shim: %s\n" % path)
    sys.exit(1)
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
if updated == text:
    sys.exit(0)
dir_name = str(file.parent)
fd, tmp = tempfile.mkstemp(prefix=".paperclip-shim.", dir=dir_name)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(updated)
    os.chmod(tmp, 0o755)
    # Keep paperclip ownership if present
    st = file.stat()
    os.chown(tmp, st.st_uid, st.st_gid)
    os.replace(tmp, path)
except Exception:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
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
