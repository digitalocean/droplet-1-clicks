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
mkdir -p /etc/exa
echo "${TARGET_VERSION}" > "$VERSION_FILE"
chmod 644 "$VERSION_FILE"

echo "Updated to $(npm list -g exa-mcp-server --depth=0 2>/dev/null | tail -n 1 || echo "$TARGET_VERSION")"
echo "MCP clients should keep using: /opt/run-exa-mcp.sh"
