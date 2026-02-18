#!/bin/bash

# Display the installed OpenCode version

if command -v opencode >/dev/null 2>&1; then
  opencode --version
else
  echo "OpenCode not found in PATH. Check /root/.opencode/bin/"
  if [ -f /root/.opencode/bin/opencode ]; then
    /root/.opencode/bin/opencode --version 2>/dev/null || echo "Version check failed"
  fi
fi
