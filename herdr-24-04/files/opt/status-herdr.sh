#!/bin/bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/grok/bin:/root/.local/bin:/root/.opencode/bin:${PATH}"

echo "Service: $(systemctl is-active herdr.service 2>/dev/null || echo unknown)"
systemctl status herdr.service --no-pager || true
echo
for cmd in herdr claude codex opencode grok kilo cursor-agent; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "${cmd}: $($cmd --version 2>&1 | head -n 1)"
    else
        echo "${cmd}: not installed"
    fi
done
echo
herdr integration status || true
