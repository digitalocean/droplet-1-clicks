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
# Only OpenShell sandbox containers (name matching ^openshell) are targeted.
#
# Usage:
#   /opt/patch-nemoclaw-sandbox-node.sh patch [NEMOCLAW_SRC]
#   /opt/patch-nemoclaw-sandbox-node.sh remediate-sandbox
#   /opt/patch-nemoclaw-sandbox-node.sh verify-sandbox
#   /opt/patch-nemoclaw-sandbox-node.sh self-test
#
# Trackers: VULN-5695 / VULN-5716.

set -euo pipefail

NODE_CVE_MIN="${NODE_CVE_MIN:-24.22.1}"
SANDBOX_NODE_FROM="node:24.22.1-trixie-slim@sha256:43b9ba1142b8dcf33fa8f922ca1be85714adc444e0586c7cf7726daaeabc1bea"
VULN_NODE_FROM="node:24.18.1-trixie-slim@sha256:ac39e4b5fcb2b1b34b20364fd58b2e898f3bb80731ee6f62a7536f9df3d6aadc"
# Wait for onboard's OpenShell container to expose node (seconds).
SANDBOX_NODE_WAIT_SECS="${SANDBOX_NODE_WAIT_SECS:-180}"
SANDBOX_NODE_POLL_SECS="${SANDBOX_NODE_POLL_SECS:-3}"

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

# OpenShell sandbox names look like: openshell-default--my-assistant-<uuid>
is_openshell_sandbox_name() {
  case "$1" in
    openshell*) return 0 ;;
    *) return 1 ;;
  esac
}

# Print running OpenShell sandbox container IDs (one per line).
list_openshell_sandbox_ids() {
  local id name
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id="${line%% *}"
    name="${line#* }"
    if is_openshell_sandbox_name "$name"; then
      printf '%s\n' "$id"
    fi
  done <<EOF
$(docker ps --format '{{.ID}} {{.Names}}' 2>/dev/null || true)
EOF
}

container_node_version() {
  local cid="$1"
  docker exec "$cid" env PATH="/usr/local/bin:/usr/bin:/bin" node -v 2>/dev/null || true
}

# Block until at least one OpenShell sandbox exposes node -v, or time out.
wait_for_openshell_node() {
  local deadline now cid ver
  deadline=$((SECONDS + SANDBOX_NODE_WAIT_SECS))

  echo "Waiting up to ${SANDBOX_NODE_WAIT_SECS}s for OpenShell sandbox node..."
  while true; do
    while IFS= read -r cid; do
      [ -n "$cid" ] || continue
      ver="$(container_node_version "$cid")"
      case "$ver" in
        v*)
          echo "  Found sandbox ${cid} with ${ver}"
          return 0
          ;;
      esac
    done <<EOF
$(list_openshell_sandbox_ids)
EOF

    now=$SECONDS
    if [ "$now" -ge "$deadline" ]; then
      echo "ERROR: timed out waiting for an OpenShell sandbox with node -v (waited ${SANDBOX_NODE_WAIT_SECS}s)" >&2
      echo "ERROR: onboard may still be starting; re-run: /opt/patch-nemoclaw-sandbox-node.sh remediate-sandbox" >&2
      exit 1
    fi
    sleep "$SANDBOX_NODE_POLL_SECS"
  done
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

  wait_for_openshell_node

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
    ver="$(container_node_version "$cid")"
    case "$ver" in
      v*) ;;
      *) continue ;;
    esac
    if node_meets_cve_floor "$ver"; then
      echo "OK: sandbox ${cid} already has ${ver}"
      continue
    fi

    echo "Remediating sandbox ${cid} (${ver} → ${NODE_CVE_MIN}) via node-binary inject..."
    inject_node_into_container "$cid" "${_HOST_NODE_BIN}"
    remediations=$((remediations + 1))
  done <<EOF
$(list_openshell_sandbox_ids)
EOF

  cleanup_node_inject
  trap - EXIT

  if [ "$remediations" -eq 0 ]; then
    verify_sandbox_node
  else
    echo "Remediated ${remediations} OpenShell sandbox container(s) for CVE-2026-111497."
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

  wait_for_openshell_node

  while IFS= read -r cid; do
    [ -n "$cid" ] || continue
    ver="$(container_node_version "$cid")"
    case "$ver" in
      v*)
        assert_node_meets_cve_floor "sandbox ${cid}" "$ver"
        checked=$((checked + 1))
        ;;
    esac
  done <<EOF
$(list_openshell_sandbox_ids)
EOF

  if [ "$checked" -eq 0 ]; then
    echo "ERROR: no OpenShell sandbox exposed node -v; cannot confirm CVE fix" >&2
    exit 1
  fi
  echo "Sandbox Node CVE-2026-111497 check passed (${checked} OpenShell container(s))."
}

self_test() {
  local failures=0
  local saved_min

  pass() { echo "  OK: $*"; }
  fail() { echo "  FAIL: $*"; failures=$((failures + 1)); }

  echo "=== patch-nemoclaw-sandbox-node self-test ==="

  saved_min="$NODE_CVE_MIN"
  NODE_CVE_MIN=24.22.1

  if version_ge "24.22.1" "24.22.1"; then pass "version_ge equal"; else fail "version_ge equal"; fi
  if version_ge "24.22.2" "24.22.1"; then pass "version_ge newer"; else fail "version_ge newer"; fi
  if ! version_ge "24.18.1" "24.22.1"; then pass "version_ge older rejects"; else fail "version_ge older rejects"; fi

  if node_meets_cve_floor "v24.22.1"; then pass "floor accepts v24.22.1"; else fail "floor accepts v24.22.1"; fi
  if ! node_meets_cve_floor "v24.18.1"; then pass "floor rejects v24.18.1"; else fail "floor rejects v24.18.1"; fi
  if ! node_meets_cve_floor "24.22.1"; then pass "floor rejects missing v prefix"; else fail "floor rejects missing v prefix"; fi
  if ! node_meets_cve_floor "v20.19.0"; then pass "floor rejects wrong major"; else fail "floor rejects wrong major"; fi

  if is_openshell_sandbox_name "openshell-default--my-assistant-a1a28b5e"; then
    pass "openshell name match"
  else
    fail "openshell name match"
  fi
  if ! is_openshell_sandbox_name "redis"; then pass "non-openshell name reject"; else fail "non-openshell name reject"; fi
  if ! is_openshell_sandbox_name "my-openshell-helper"; then
    # prefix-only: require names starting with openshell
    pass "mid-string openshell reject"
  else
    # Actually is_openshell_sandbox_name uses openshell* which is prefix. "my-openshell-helper" should reject.
    fail "mid-string openshell reject"
  fi

  NODE_CVE_MIN="$saved_min"

  if [ "$failures" -ne 0 ]; then
    echo "self-test FAILED (${failures})" >&2
    exit 1
  fi
  echo "self-test passed"
}

usage() {
  cat <<'EOF'
Usage:
  /opt/patch-nemoclaw-sandbox-node.sh patch [NEMOCLAW_SRC]
  /opt/patch-nemoclaw-sandbox-node.sh remediate-sandbox
  /opt/patch-nemoclaw-sandbox-node.sh verify-sandbox
  /opt/patch-nemoclaw-sandbox-node.sh self-test
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
  self-test)
    self_test
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
