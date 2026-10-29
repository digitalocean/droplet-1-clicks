#!/bin/bash
# Packer records application_version before 010-t3code.sh resolves "latest".
# Replace that placeholder with the versions chosen for this build.
set -euo pipefail

resolved=/var/lib/digitalocean/t3code-resolved.env
info=/var/lib/digitalocean/application.info
[ -f "$resolved" ] || exit 0
# shellcheck disable=SC1090
. "$resolved"

if [ -f "$info" ] && [ -n "${application_version:-}" ]; then
  sed -i "s|^application_version=.*|application_version=${application_version}|" "$info"
fi

cat >> "$info" << EOF
node_version=${node_version:-}
claude_version=${claude_version:-}
codex_version=${codex_version:-}
cursor_version=${cursor_version:-}
grok_version=${grok_version:-}
opencode_version=${opencode_version:-}
pi_version=${pi_version:-}
fx_version=${fx_version:-}
antigravity_version=${antigravity_version:-}
EOF
