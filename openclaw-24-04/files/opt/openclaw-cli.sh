#!/bin/bash
# Run OpenClaw CLI as the openclaw user (arguments preserved and shell-safe).
if [ "$#" -eq 0 ]; then
  exec su - openclaw -c "openclaw"
fi
cmd="openclaw"
for a in "$@"; do
  cmd+=" $(printf '%q' "$a")"
done
exec su - openclaw -c "$cmd"
