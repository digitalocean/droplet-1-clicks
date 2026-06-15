#!/bin/bash

# Grok Build Update Script
# Re-runs the official installer to fetch the latest stable Grok Build binary.

set -e

export GROK_BIN_DIR="${GROK_BIN_DIR:-$HOME/.grok/bin}"
[ -d "$GROK_BIN_DIR" ] && export PATH="$GROK_BIN_DIR:$PATH"

echo "Updating Grok Build to the latest stable release..."
curl -fsSL https://x.ai/cli/install.sh | bash

echo "Grok Build updated successfully!"
"${GROK_BIN_DIR}/grok" --version 2>/dev/null || grok --version 2>/dev/null || echo "Version check failed"
