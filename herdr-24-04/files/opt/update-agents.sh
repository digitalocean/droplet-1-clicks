#!/bin/bash

# Update the preinstalled coding agents to the latest stable release, then
# refresh Herdr's session-restore integrations.

set -euo pipefail

export PATH="/usr/local/bin:/opt/grok/bin:/root/.local/bin:/root/.opencode/bin:${PATH}"
export GROK_BIN_DIR="${GROK_BIN_DIR:-/opt/grok/bin}"

# shellcheck source=/dev/null
source /opt/run-remote-installer.sh

echo "Updating Claude Code..."
run_remote_installer https://claude.ai/install.sh bash -- latest
ln -sfn /root/.local/bin/claude /usr/local/bin/claude

echo "Updating Codex CLI..."
tag="$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest | jq -r '.tag_name')"
tmpdir="$(mktemp -d)"
# shellcheck source=/dev/null
source /opt/codex-cli-download.sh
install_codex_binaries "$tag" "$tmpdir"
rm -rf "$tmpdir"
install -m 0755 /opt/codex-bin-wrapper.sh /usr/local/bin/codex

echo "Updating OpenCode..."
run_remote_installer https://opencode.ai/install bash -- --no-modify-path
ln -sfn /root/.opencode/bin/opencode /usr/local/bin/opencode

echo "Updating Grok Build..."
mkdir -p "$GROK_BIN_DIR"
run_remote_installer https://x.ai/cli/install.sh bash
ln -sfn "${GROK_BIN_DIR}/grok" /usr/local/bin/grok

echo "Updating Kilo Code CLI..."
npm install --global @kilocode/cli@latest

echo "Updating Cursor Agent CLI..."
run_remote_installer https://cursor.com/install bash
ln -sfn /root/.local/bin/cursor-agent /usr/local/bin/cursor-agent

echo "Refreshing Herdr integrations..."
/opt/install-herdr-integrations.sh

echo "Agents updated."
/opt/status-herdr.sh
