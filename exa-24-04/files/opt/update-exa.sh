#!/bin/bash
# Update the globally installed exa-mcp-server package.
# Usage: /opt/update-exa.sh [version]
# Default version is from /etc/exa/version (build pin). Pass a version to bump.
set -euo pipefail

VERSION_FILE="/etc/exa/version"
TARGET_VERSION="${1:-}"

if [ -z "$TARGET_VERSION" ]; then
  if [ -f "$VERSION_FILE" ]; then
    TARGET_VERSION="$(cat "$VERSION_FILE")"
  else
    echo "No version specified and ${VERSION_FILE} is missing." >&2
    exit 1
  fi
fi

echo "==> Installing exa-mcp-server@${TARGET_VERSION}..."
npm install -g "exa-mcp-server@${TARGET_VERSION}"

PKG_ROOT="$(npm root -g)/exa-mcp-server"
if [ ! -f "${PKG_ROOT}/smithery/shttp/index.cjs" ] \
  && [ ! -f "${PKG_ROOT}/.smithery/shttp/index.cjs" ] \
  && [ ! -f "${PKG_ROOT}/shttp/.smithery/index.cjs" ]; then
  echo "Error: streamable HTTP bundle (smithery/shttp) not found for exa-mcp-server@${TARGET_VERSION}" >&2
  echo "This 1-Click needs a release that ships smithery/shttp (e.g. 3.2.x)." >&2
  exit 1
fi

mkdir -p /etc/exa
echo "${TARGET_VERSION}" > "$VERSION_FILE"
chmod 644 "$VERSION_FILE"

if [ -f /etc/exa/.configured ]; then
  systemctl restart exa-mcp || true
fi

echo "Updated to $(npm list -g exa-mcp-server --depth=0 2>/dev/null | tail -n 1 || echo "$TARGET_VERSION")"
echo "Remote MCP URL remains: https://<droplet-ip>/mcp"
echo "Optional stdio entrypoint: /opt/run-exa-mcp.sh"
