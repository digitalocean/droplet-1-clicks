#!/bin/bash
# Remediate NemoClaw sandbox Node for CVE-2026-111497 (Brotli RCE).
#
# Stock `nemoclaw onboard` pulls an immutable managed GHCR image that still
# ships Node 24.18.1 on lkg. Editing Dockerfile.base does not fix that path.
#
# After onboard, replace *only* /usr/local/bin/node in the running sandbox
# (CVE is in the Node binary), then restart the container so long-lived Node
# processes reload the patched binary. Do NOT overlay all of /usr/local — that
# wipes OpenClaw and other sandbox packages and puts the sandbox into Error.
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
# Hermes overlays Node from nodejs.org tarballs (not the OpenClaw FROM pin).
HERMES_NODE_VERSION="24.22.1"
HERMES_NPM_VERSION="11.19.1"
HERMES_NODE_SHA_AMD64="eb6728e77c576a35162c122c45ccadf224d89ff00abc8dae46cc2897c6002d7c"
HERMES_NODE_SHA_ARM64="33c37be234ba8bee041961047b19160f4d7d0f164e8e246f78bdd10feff148b3"
VULN_HERMES_NODE_SHA_AMD64="9f5eb6ac21845a66c493c91a253b1da32fd684e89e9b7202d4936982336be4ca"
VULN_HERMES_NODE_SHA_ARM64="df224555a083b918e46260cc969838501b9f9a87140c1195e5b9597b56d5dae2"
# Wait for onboard's OpenShell container to expose node (seconds).
SANDBOX_NODE_WAIT_SECS="${SANDBOX_NODE_WAIT_SECS:-180}"
SANDBOX_NODE_POLL_SECS="${SANDBOX_NODE_POLL_SECS:-3}"
SANDBOX_RESTART_WAIT_SECS="${SANDBOX_RESTART_WAIT_SECS:-120}"

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

# Hermes installs Node via nodejs.org tarball + arch checksums, not OpenClaw's
# digest-pinned FROM line.
is_hermes_tarball_node_dockerfile() {
  grep -q 'ARG NODE_VERSION=' "$1" \
    && grep -q 'nodejs.org/dist' "$1"
}

hermes_dockerfile_already_patched() {
  local f="$1"
  grep -Fq "ARG NODE_VERSION=${HERMES_NODE_VERSION}" "$f" \
    && grep -Fq "$HERMES_NODE_SHA_AMD64" "$f" \
    && grep -Fq "$HERMES_NODE_SHA_ARM64" "$f" \
    && ! grep -Fq '24.18.1' "$f" \
    && ! grep -Fq "$VULN_HERMES_NODE_SHA_AMD64" "$f" \
    && ! grep -Fq "$VULN_HERMES_NODE_SHA_ARM64" "$f"
}

patch_openclaw_dockerfile() {
  local f="$1"
  local tmp

  if grep -Fq "$SANDBOX_NODE_FROM" "$f" \
    && ! grep -Fq '24.18.1' "$f"
  then
    echo "Already patched for CVE-2026-111497: ${f}"
    return 1
  fi

  echo "Patching OpenClaw sandbox Node pin in ${f} (defense-in-depth for --from builds)..."
  tmp="${f}.cve-patch.tmp"
  sed "s|${VULN_NODE_FROM}|${SANDBOX_NODE_FROM}|g; s/24\\.18\\.1/24.22.1/g" "$f" >"$tmp"
  mv "$tmp" "$f"

  if ! grep -Fq "$SANDBOX_NODE_FROM" "$f" || grep -Fq '24.18.1' "$f"; then
    echo "ERROR: failed to apply sandbox Node CVE pin in ${f}" >&2
    exit 1
  fi
  echo "  OK: ${f}"
  return 0
}

patch_hermes_dockerfile() {
  local f="$1"
  local tmp

  if hermes_dockerfile_already_patched "$f"; then
    echo "Already patched for CVE-2026-111497: ${f}"
    return 1
  fi

  if ! grep -Fq 'ARG NODE_VERSION=24.18.1' "$f" \
    && ! grep -Fq "$VULN_HERMES_NODE_SHA_AMD64" "$f" \
    && ! grep -Fq '24.18.1' "$f"
  then
    echo "Skipping ${f}: no vulnerable Hermes Node 24.18.1 tarball pin (ok)."
    return 1
  fi

  echo "Patching Hermes sandbox Node tarball pin in ${f} (defense-in-depth for --from builds)..."
  tmp="${f}.cve-patch.tmp"
  sed \
    -e "s/ARG NODE_VERSION=24\\.18\\.1/ARG NODE_VERSION=${HERMES_NODE_VERSION}/g" \
    -e "s/24\\.18\\.1/${HERMES_NODE_VERSION}/g" \
    -e "s/test \"\$(npm --version)\" = \"11\\.16\\.0\"/test \"\$(npm --version)\" = \"${HERMES_NPM_VERSION}\"/g" \
    -e "s/npm 11\\.16\\.0/npm ${HERMES_NPM_VERSION}/g" \
    -e "s|node_sha256=\"${VULN_HERMES_NODE_SHA_AMD64}\"|node_sha256=\"${HERMES_NODE_SHA_AMD64}\"|g" \
    -e "s|node_sha256=\"${VULN_HERMES_NODE_SHA_ARM64}\"|node_sha256=\"${HERMES_NODE_SHA_ARM64}\"|g" \
    "$f" >"$tmp"
  mv "$tmp" "$f"

  if ! hermes_dockerfile_already_patched "$f"; then
    echo "ERROR: failed to apply Hermes Node CVE tarball pin in ${f}" >&2
    exit 1
  fi
  echo "  OK: ${f}"
  return 0
}

patch_dockerfiles() {
  local src="${1:-${HOME}/.nemoclaw/source}"
  local patched=0
  local f

  if [ ! -d "$src" ]; then
    echo "ERROR: NemoClaw source not found at ${src}" >&2
    exit 1
  fi

  for f in \
    "${src}/Dockerfile.base" \
    "${src}/agents/hermes/Dockerfile.base"
  do
    [ -f "$f" ] || continue

    if is_hermes_tarball_node_dockerfile "$f"; then
      if patch_hermes_dockerfile "$f"; then
        patched=$((patched + 1))
      fi
    else
      if patch_openclaw_dockerfile "$f"; then
        patched=$((patched + 1))
      fi
    fi
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

# Wait until a restarted sandbox answers node -v again.
wait_for_container_node() {
  local cid="$1"
  local label="$2"
  local deadline now ver

  deadline=$((SECONDS + SANDBOX_RESTART_WAIT_SECS))
  while true; do
    ver="$(container_node_version "$cid")"
    case "$ver" in
      v*)
        printf '%s\n' "$ver"
        return 0
        ;;
    esac
    now=$SECONDS
    if [ "$now" -ge "$deadline" ]; then
      echo "ERROR: sandbox '${label}' did not expose node -v within ${SANDBOX_RESTART_WAIT_SECS}s after restart" >&2
      exit 1
    fi
    sleep "$SANDBOX_NODE_POLL_SECS"
  done
}

# Fail if any running node process still maps a different binary than
# /usr/local/bin/node (hot-patch without restart leaves stale inodes).
assert_running_node_matches_ondisk() {
  local cid="$1"
  local label="$2"
  local stale

  stale="$(docker exec -u 0 "$cid" sh -c '
    node_bin=/usr/local/bin/node
    if [ ! -x "$node_bin" ]; then
      echo "missing-node-bin"
      exit 0
    fi
    bin_sum=$(sha256sum "$node_bin" | awk "{print \$1}")
    for exe in /proc/[0-9]*/exe; do
      [ -L "$exe" ] || continue
      target=$(readlink -f "$exe" 2>/dev/null || true)
      case "$target" in
        */bin/node|*/bin/nodejs) ;;
        *) continue ;;
      esac
      proc_sum=$(sha256sum "$exe" 2>/dev/null | awk "{print \$1}" || true)
      if [ -z "$proc_sum" ] || [ "$proc_sum" != "$bin_sum" ]; then
        pid=${exe#/proc/}
        pid=${pid%/exe}
        echo "$pid"
      fi
    done
  ' 2>/dev/null || true)"

  case "$stale" in
    missing-node-bin)
      echo "ERROR: sandbox '${label}': /usr/local/bin/node missing during running-process check" >&2
      exit 1
      ;;
    "")
      return 0
      ;;
  esac
  echo "ERROR: sandbox '${label}': running node PID(s) still map the pre-patch binary: ${stale}" >&2
  echo "ERROR: restart the OpenShell sandbox so workloads load the remediated node" >&2
  exit 1
}

# Replace only /usr/local/bin/node in the sandbox (preserves OpenClaw under
# /usr/local/lib/node_modules and OpenShell identity/network), then restart so
# long-lived Node processes reload the patched binary.
inject_node_into_container() {
  local cid="$1"
  local host_node="$2"
  local name ver

  name="$(docker inspect -f '{{.Name}}' "$cid" | sed 's#^/##')"

  docker exec -u 0 "$cid" mkdir -p /usr/local/bin
  docker cp "${host_node}" "${cid}:/usr/local/bin/node"
  docker exec -u 0 "$cid" chmod 755 /usr/local/bin/node

  echo "  Restarting sandbox '${name}' so running Node processes load the patched binary..."
  docker restart "$cid" >/dev/null

  ver="$(wait_for_container_node "$cid" "$name")"
  if ! node_meets_cve_floor "$ver"; then
    echo "ERROR: sandbox '${name}' still has Node ${ver:-missing} after inject+restart" >&2
    exit 1
  fi
  assert_running_node_matches_ondisk "$cid" "$name"

  echo "  OK: sandbox '${name}' now ${ver} (node binary only; restarted; OpenClaw tree left intact)"
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
        assert_running_node_matches_ondisk "$cid" "$cid"
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
  echo "Sandbox Node CVE-2026-111497 check passed (${checked} OpenShell container(s); on-disk + running process)."
}

self_test() {
  local failures=0
  local saved_min
  local hermes_tmp openclaw_tmp

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

  hermes_tmp="$(mktemp)"
  openclaw_tmp="$(mktemp)"
  cat >"$hermes_tmp" <<EOF
ARG NODE_VERSION=24.18.1
RUN curl -fsSL "https://nodejs.org/dist/v\${NODE_VERSION}/node-v\${NODE_VERSION}-linux-x64.tar.gz"
 amd64) node_asset_arch="x64"; node_sha256="${VULN_HERMES_NODE_SHA_AMD64}" ;;
 arm64) node_asset_arch="arm64"; node_sha256="${VULN_HERMES_NODE_SHA_ARM64}" ;;
 && test "\$(npm --version)" = "11.16.0"
EOF
  cat >"$openclaw_tmp" <<EOF
FROM ${VULN_NODE_FROM}
# node 24.18.1
EOF

  if is_hermes_tarball_node_dockerfile "$hermes_tmp"; then
    pass "hermes tarball dockerfile detect"
  else
    fail "hermes tarball dockerfile detect"
  fi
  if ! is_hermes_tarball_node_dockerfile "$openclaw_tmp"; then
    pass "openclaw dockerfile not hermes"
  else
    fail "openclaw dockerfile not hermes"
  fi

  if patch_hermes_dockerfile "$hermes_tmp"; then
    if hermes_dockerfile_already_patched "$hermes_tmp"; then
      pass "hermes dockerfile patch"
    else
      fail "hermes dockerfile patch validation"
    fi
  else
    fail "hermes dockerfile patch apply"
  fi
  if patch_openclaw_dockerfile "$openclaw_tmp"; then
    if grep -Fq "$SANDBOX_NODE_FROM" "$openclaw_tmp" && ! grep -Fq '24.18.1' "$openclaw_tmp"; then
      pass "openclaw dockerfile patch"
    else
      fail "openclaw dockerfile patch validation"
    fi
  else
    fail "openclaw dockerfile patch apply"
  fi
  # Second pass should be no-op (return 1 / already patched).
  if ! patch_hermes_dockerfile "$hermes_tmp"; then
    pass "hermes already-patched short-circuit"
  else
    fail "hermes already-patched short-circuit"
  fi
  if ! patch_openclaw_dockerfile "$openclaw_tmp"; then
    pass "openclaw already-patched short-circuit"
  else
    fail "openclaw already-patched short-circuit"
  fi
  rm -f "$hermes_tmp" "$openclaw_tmp"

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
