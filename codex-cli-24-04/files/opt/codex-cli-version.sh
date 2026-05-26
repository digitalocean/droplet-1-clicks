#!/bin/bash

# Display the installed Codex CLI version

if command -v codex >/dev/null 2>&1; then
  codex --version
else
  echo "Codex CLI not found in PATH. Check /usr/local/bin/codex"
  if [ -f /usr/local/bin/codex ]; then
    /usr/local/bin/codex --version 2>/dev/null || echo "Version check failed"
  fi
fi
