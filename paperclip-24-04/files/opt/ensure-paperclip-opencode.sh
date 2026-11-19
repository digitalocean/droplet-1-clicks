#!/bin/bash
# Install / upgrade the OpenCode CLI on the Paperclip host.
#
# Hiring an OpenCode agent runs a local hello probe (`opencode run`) before
# the agent can leave "verifying". Paperclip only auto-installs that CLI
# inside a sandbox, so a missing host binary fails the probe and Retry
# reports "The lifecycle step failed. Retry the operation."
# Image bake fails when this cannot install. First boot and update warn and
# continue, so a later download failure does not stop Paperclip.
#
# Version comes from template.json `opencode_version` (Packer → OPENCODE_VERSION).
# SHA-256 digests are resolved dynamically from the GitHub release asset metadata
# for that tag, so bumping the Packer version alone is enough.
# The paperclip service PATH includes /usr/local/bin. Install the verified
# release binary there; do not execute a remote installer as root.
set -euo pipefail

BIN=/usr/local/bin/opencode
OPENCODE_VERSION="${OPENCODE_VERSION:-${opencode_version:-1.19.6}}"
OPENCODE_VERSION="${OPENCODE_VERSION#v}"
REPO="${OPENCODE_GITHUB_REPO:-anomalyco/opencode}"
API_URL="https://api.github.com/repos/${REPO}/releases/tags/v${OPENCODE_VERSION}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: $0" >&2
  exit 1
fi

installed_opencode_version() {
  local raw
  [ -x "$BIN" ] || return 1
  raw="$("$BIN" --version 2>/dev/null | head -n 1 || true)"
  # Accept "1.19.6", "opencode 1.19.6", "v1.19.6", etc.
  printf '%s' "$raw" | sed -E -n 's/.*v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'
}

if [ -x "$BIN" ]; then
  CURRENT="$(installed_opencode_version || true)"
  if [ -n "$CURRENT" ] && [ "$CURRENT" = "$OPENCODE_VERSION" ]; then
    echo "OpenCode ${CURRENT} already installed at ${BIN}."
    exit 0
  fi
  if [ -n "$CURRENT" ]; then
    echo "OpenCode ${CURRENT} != pin ${OPENCODE_VERSION}; upgrading..."
  else
    echo "OpenCode present but version unreadable; reinstalling ${OPENCODE_VERSION}..."
  fi
fi

asset="opencode-linux-x64.tar.gz"
if ! grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
  asset="opencode-linux-x64-baseline.tar.gz"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
meta="${tmpdir}/release.json"

echo "Resolving SHA-256 for ${asset} from ${API_URL}..."
if ! curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: paperclip-1click-opencode" \
  "$API_URL" -o "$meta"; then
  echo "ERROR: could not fetch OpenCode release metadata for v${OPENCODE_VERSION}" >&2
  exit 1
fi

expected_sha="$(
  ASSET="$asset" python3 - "$meta" <<'PY'
import json, os, sys
path = sys.argv[1]
want = os.environ["ASSET"]
data = json.load(open(path, encoding="utf-8"))
for asset in data.get("assets") or []:
    if not isinstance(asset, dict):
        continue
    if asset.get("name") != want:
        continue
    digest = asset.get("digest") or ""
    if isinstance(digest, str) and digest.startswith("sha256:"):
        print(digest.split(":", 1)[1].strip(), end="")
        raise SystemExit(0)
    raise SystemExit("missing sha256 digest for %s" % want)
raise SystemExit("asset %s not found on release" % want)
PY
)" || {
  echo "ERROR: could not resolve digest for ${asset} on v${OPENCODE_VERSION}" >&2
  exit 1
}

url="https://github.com/${REPO}/releases/download/v${OPENCODE_VERSION}/${asset}"
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
