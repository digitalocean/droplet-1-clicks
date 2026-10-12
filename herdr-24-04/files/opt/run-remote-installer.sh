#!/bin/bash
# Download a remote installer to a temp file, execute it, then remove the file.
# Avoids curl|bash pipe-to-shell while preserving the same install behavior.

set -euo pipefail

run_remote_installer() {
    local url="$1"
    local interpreter="$2"
    shift 2
    local tmp
    tmp="$(mktemp)"
    curl -fsSL "$url" -o "$tmp"
    chmod +x "$tmp"
    "$interpreter" "$tmp" "$@"
    rm -f "$tmp"
}
