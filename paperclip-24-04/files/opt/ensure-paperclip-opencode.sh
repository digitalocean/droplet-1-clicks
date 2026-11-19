#!/bin/bash
# Install the OpenCode CLI on the Paperclip host.
#
# Hiring an OpenCode agent runs a local hello probe (`opencode run`) before
# the agent can leave "verifying". Paperclip only auto-installs that CLI
# inside a sandbox, so a missing host binary fails the probe and Retry
# reports "The lifecycle step failed. Retry the operation."
# Image bake fails when this cannot install. First boot and update warn and
# continue, so a later download failure does not stop Paperclip.
# The paperclip service PATH includes /usr/local/bin. Install the verified
# release binary there; do not execute a remote installer as root.
set -euo pipefail

BIN=/usr/local/bin/opencode
# OpenCode 1.x (opencode.ai/install). Digests from GitHub release asset metadata;
# bump both version and hashes together when upgrading.
OPENCODE_VERSION="${OPENCODE_VERSION:-1.19.6}"
OPENCODE_SHA256_X64="47734e08968b30cc22a0bffb6d9feeed76ad4aa743213a12122040392d09a057"
OPENCODE_SHA256_X64_BASELINE="8443113b3f3dfebf8b0fa91c4377e5519a62b9231732d9344a5df001e4a852b3"

if [ -x "$BIN" ]; then
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: $0" >&2
  exit 1
fi

asset="opencode-linux-x64.tar.gz"
expected_sha="$OPENCODE_SHA256_X64"
if ! grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
  asset="opencode-linux-x64-baseline.tar.gz"
  expected_sha="$OPENCODE_SHA256_X64_BASELINE"
fi

url="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/${asset}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Downloading OpenCode ${OPENCODE_VERSION} (${asset})..."
curl -fsSL "$url" -o "${tmpdir}/${asset}"
echo "${expected_sha}  ${tmpdir}/${asset}" | sha256sum -c -

tar -xzf "${tmpdir}/${asset}" -C "$tmpdir"
if [ ! -f "${tmpdir}/opencode" ]; then
  echo "ERROR: OpenCode archive did not contain an opencode binary" >&2
  exit 1
fi

install -m 755 "${tmpdir}/opencode" "$BIN"
"$BIN" --version
