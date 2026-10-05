#!/bin/bash

set -euo pipefail

export PATH="/usr/local/bin:/opt/grok/bin:/root/.local/bin:/root/.opencode/bin:${PATH}"

# Herdr refuses to install an integration unless that agent's config directory
# already exists. Create the directories the official integrations write into.
mkdir -p \
    /root/.claude \
    /root/.codex \
    /root/.config/opencode \
    /root/.config/kilo \
    /root/.grok \
    /root/.cursor

for kind in claude codex opencode kilo grok cursor; do
    echo "Installing Herdr integration: ${kind}"
    herdr integration install "${kind}"
done

herdr integration status
