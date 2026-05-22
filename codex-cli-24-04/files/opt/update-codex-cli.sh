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
ARCH="x86_64-unknown-linux-musl"
CODEX_URL="https://github.com/openai/codex/releases/download/${LATEST_TAG}/codex-${ARCH}.tar.gz"
BWRAP_URL="https://github.com/openai/codex/releases/download/${LATEST_TAG}/bwrap-${ARCH}.tar.gz"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

CODEX_LIB_DIR=/usr/local/lib/codex
mkdir -p "$CODEX_LIB_DIR"

echo "Updating Codex CLI to ${VERSION}..."
curl -fsSL "$CODEX_URL" -o "${tmpdir}/codex.tar.gz"
tar -xzf "${tmpdir}/codex.tar.gz" -C "${tmpdir}"
install -m 0755 "${tmpdir}/codex-${ARCH}" "${CODEX_LIB_DIR}/codex"

curl -fsSL "$BWRAP_URL" -o "${tmpdir}/bwrap.tar.gz"
tar -xzf "${tmpdir}/bwrap.tar.gz" -C "${tmpdir}"
install -m 0755 "${tmpdir}/bwrap-${ARCH}" /usr/local/bin/bwrap

echo "Codex CLI updated successfully!"
codex --version 2>/dev/null || echo "Version check failed"
