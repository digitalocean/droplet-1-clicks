#!/bin/bash
# Remediate NemoClaw sandbox Node for CVE-2026-111497 (Brotli RCE).
#
# Stock `nemoclaw onboard` pulls an immutable managed GHCR image that still
# ships Node 24.18.1 on lkg. Editing Dockerfile.base does not fix that path.
#
# After onboard, replace *only* /usr/local/bin/node in the running sandbox
# (CVE is in the Node binary). Do NOT overlay all of /usr/local — that wipes
# OpenClaw and other sandbox packages and puts the sandbox into Error.
# Stage via the host because docker cp cannot go container→container.
#
# Usage:
#   /opt/patch-nemoclaw-sandbox-node.sh patch [NEMOCLAW_SRC]
#   /opt/patch-nemoclaw-sandbox-node.sh remediate-sandbox
#   /opt/patch-nemoclaw-sandbox-node.sh verify-sandbox
#
# Trackers: VULN-5695 / VULN-5716.

set -euo pipefail

NODE_CVE_MIN="${NODE_CVE_MIN:-24.22.1}"
SANDBOX_NODE_FROM="node:24.22.1-trixie-slim@sha256:43b9ba1142b8dcf33fa8f922ca1be85714adc444e0586c7cf7726daaeabc1bea"
VULN_NODE_FROM="node:24.18.1-trixie-slim@sha256:ac39e4b5fcb2b1b34b20364fd58b2e898f3bb80731ee6f62a7536f9df3d6aadc"

version_ge() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]
}

node_meets_cve_floor() {
  local ver="$1"
  local actual maj

  case "$ver" in
    v*) ;;
    *) return 1 ;;
  esac
  actual="${ver#v}"
  maj="${actual%%.*}"
  case "$maj" in
    24) version_ge "$actual" "$NODE_CVE_MIN" ;;
    22) version_ge "$actual" "22.23.4" ;;
    26) version_ge "$actual" "26.12.1" ;;
    *) return 1 ;;
  esac
}

patch_dockerfiles() {
  local src="${1:-${HOME}/.nemoclaw/source}"
  local patched=0
  local f tmp

  if [ ! -d "$src" ]; then
    echo "ERROR: NemoClaw source not found at ${src}" >&2
    exit 1
  fi

  for f in \
    "${src}/Dockerfile.base" \
    "${src}/agents/hermes/Dockerfile.base"
  do
    [ -f "$f" ] || continue

    if grep -Fq "$SANDBOX_NODE_FROM" "$f" \
      && ! grep -Fq '24.18.1' "$f"
    then
      echo "Already patched for CVE-2026-111497: ${f}"
      continue
    fi

    echo "Patching sandbox Node pin in ${f} (defense-in-depth for --from builds)..."
    tmp="${f}.cve-patch.tmp"
    sed "s|${VULN_NODE_FROM}|${SANDBOX_NODE_FROM}|g; s/24\\.18\\.1/24.22.1/g" "$f" >"$tmp"
    mv "$tmp" "$f"

    if ! grep -Fq "$SANDBOX_NODE_FROM" "$f" || grep -Fq '24.18.1' "$f"; then
      echo "ERROR: failed to apply sandbox Node CVE pin in ${f}" >&2
      exit 1
    fi
    patched=$((patched + 1))
    echo "  OK: ${f}"
  done

  if [ "$patched" -eq 0 ]; then
    echo "No vulnerable sandbox Dockerfile pins under ${src} (ok)."
  fi

  if mkdir -p /etc/profile.d 2>/dev/null \
    && cat > /etc/profile.d/nemoclaw-sandbox-node.sh <<EOF
export NODE_CVE_MIN=${NODE_CVE_MIN}
EOF
  then
    chmod 644 /etc/profile.d/nemoclaw-sandbox-node.sh
  fi
}

assert_node_meets_cve_floor() {
  local label="$1"
  local ver="$2"

  if node_meets_cve_floor "$ver"; then
    echo "${label}: node ${ver}"
    return 0
  fi
  echo "ERROR: ${label}: Node ${ver} is below CVE-2026-111497 floor (need 24.x >= ${NODE_CVE_MIN}, or 22.23.4 / 26.12.1)" >&2
  exit 1
}

# Cleanup paths for EXIT trap (must be global; locals are unbound when trap runs).
_DONOR_CID=""
_HOST_NODE_BIN=""

cleanup_node_inject() {
  if [ -n "${_DONOR_CID}" ]; then
    docker rm -f "${_DONOR_CID}" >/dev/null 2>&1 || true
    _DONOR_CID=""
  fi
  if [ -n "${_HOST_NODE_BIN}" ] && [ -e "${_HOST_NODE_BIN}" ]; then
    rm -f "${_HOST_NODE_BIN}"
    rmdir "$(dirname "${_HOST_NODE_BIN}")" 2>/dev/null || true
    _HOST_NODE_BIN=""
  fi
}

# Replace only /usr/local/bin/node in the sandbox (preserves OpenClaw under
# /usr/local/lib/node_modules and OpenShell identity/network).
inject_node_into_container() {
  local cid="$1"
  local host_node="$2"
  local name ver

  name="$(docker inspect -f '{{.Name}}' "$cid" | sed 's#^/##')"

  docker exec -u 0 "$cid" mkdir -p /usr/local/bin
  docker cp "${host_node}" "${cid}:/usr/local/bin/node"
  docker exec -u 0 "$cid" chmod 755 /usr/local/bin/node

  ver="$(docker exec -u 0 "$cid" env PATH="/usr/local/bin:/usr/bin:/bin" node -v 2>/dev/null || true)"
  if ! node_meets_cve_floor "$ver"; then
    echo "ERROR: sandbox '${name}' still has Node ${ver:-missing} after inject" >&2
    exit 1
  fi

  echo "  OK: sandbox '${name}' now ${ver} (node binary only; OpenClaw tree left intact)"
}

remediate_sandbox_node() {
  local cid ver remediations=0

  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found" >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: docker is not running" >&2
    exit 1
  fi

  echo "Pulling patched Node donor image ${SANDBOX_NODE_FROM}..."
  docker pull "$SANDBOX_NODE_FROM"

  # Extract only the node binary; docker cp cannot go container→container.
  _DONOR_CID="$(docker create "$SANDBOX_NODE_FROM")"
  _HOST_NODE_BIN="$(mktemp /tmp/nemoclaw-node-cve.XXXXXX)"
  trap cleanup_node_inject EXIT
  echo "Staging patched node binary from donor onto host..."
  docker cp "${_DONOR_CID}:/usr/local/bin/node" "${_HOST_NODE_BIN}"
  docker rm -f "${_DONOR_CID}" >/dev/null 2>&1 || true
  _DONOR_CID=""

  if [ ! -s "${_HOST_NODE_BIN}" ]; then
    echo "ERROR: staged donor node binary missing or empty at ${_HOST_NODE_BIN}" >&2
    exit 1
  fi

  while IFS= read -r cid; do
    [ -n "$cid" ] || continue
    ver="$(docker exec "$cid" env PATH="/usr/local/bin:/usr/bin:/bin" node -v 2>/dev/null || true)"
    case "$ver" in
      v*) ;;
      *) continue ;;
    esac
    if node_meets_cve_floor "$ver"; then
      echo "OK: container ${cid} already has ${ver}"
      continue
    fi

    echo "Remediating container ${cid} (${ver} → ${NODE_CVE_MIN}) via node-binary inject..."
    inject_node_into_container "$cid" "${_HOST_NODE_BIN}"
    remediations=$((remediations + 1))
  done <<EOF
$(docker ps -q)
EOF

  cleanup_node_inject
  trap - EXIT

  if [ "$remediations" -eq 0 ]; then
    verify_sandbox_node
  else
    echo "Remediated ${remediations} sandbox container(s) for CVE-2026-111497."
    verify_sandbox_node
  fi
}

verify_sandbox_node() {
  local cid ver checked=0

  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found; cannot verify sandbox Node" >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: docker is not running; cannot verify sandbox Node" >&2
    exit 1
  fi

  while IFS= read -r cid; do
    [ -n "$cid" ] || continue
    ver="$(docker exec "$cid" env PATH="/usr/local/bin:/usr/bin:/bin" node -v 2>/dev/null || true)"
    case "$ver" in
      v*)
        assert_node_meets_cve_floor "container ${cid}" "$ver"
        checked=$((checked + 1))
        ;;
    esac
  done <<EOF
$(docker ps -q)
EOF

  if [ "$checked" -eq 0 ]; then
    echo "ERROR: no sandbox container exposed node -v; cannot confirm CVE fix" >&2
    exit 1
  fi
  echo "Sandbox Node CVE-2026-111497 check passed (${checked} container(s))."
}

usage() {
  cat <<'EOF'
Usage:
  /opt/patch-nemoclaw-sandbox-node.sh patch [NEMOCLAW_SRC]
  /opt/patch-nemoclaw-sandbox-node.sh remediate-sandbox
  /opt/patch-nemoclaw-sandbox-node.sh verify-sandbox
EOF
}

cmd="${1:-}"
case "$cmd" in
  patch)
    patch_dockerfiles "${2:-${HOME}/.nemoclaw/source}"
    ;;
  remediate-sandbox)
    remediate_sandbox_node
    ;;
  verify-sandbox)
    verify_sandbox_node
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
