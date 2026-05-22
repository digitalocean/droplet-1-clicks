#!/bin/bash

# Codex CLI Update Script
# Updates Codex CLI to the latest GitHub release binary

set -e

echo "Fetching latest Codex CLI release..."

LATEST_TAG=$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | jq -r '.tag_name')
if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
  echo "Error: Could not determine latest Codex CLI version"
  exit 1
fi

VERSION="${LATEST_TAG#rust-v}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# shellcheck source=/dev/null
source /opt/codex-cli-download.sh

echo "Updating Codex CLI to ${VERSION}..."
install_codex_binaries "$LATEST_TAG" "$tmpdir"

echo "Codex CLI updated successfully!"
codex --version 2>/dev/null || echo "Version check failed"
