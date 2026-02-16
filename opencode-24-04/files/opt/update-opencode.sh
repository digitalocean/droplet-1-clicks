#!/bin/bash

# OpenCode Update Script
# Updates OpenCode to the latest version by re-running the install script

echo "Updating OpenCode to the latest version..."

curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path

echo "OpenCode updated successfully!"
echo "Current version: $(opencode --version 2>/dev/null || echo 'unknown')"
