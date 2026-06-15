#!/bin/bash

# Display the installed Grok Build version

GROK_BIN="${GROK_BIN_DIR:-$HOME/.grok/bin}/grok"
[ -x "$GROK_BIN" ] || GROK_BIN="/root/.grok/bin/grok"

if command -v grok >/dev/null 2>&1; then
  grok --version
elif [ -x "$GROK_BIN" ]; then
  "$GROK_BIN" --version
else
  echo "Grok Build not found. Check /root/.grok/bin/grok"
fi
