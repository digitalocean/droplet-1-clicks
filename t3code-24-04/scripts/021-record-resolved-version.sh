#!/bin/bash
# Packer records application_version before 010-t3code.sh resolves "latest".
# Replace that placeholder with the versions chosen for this build.
set -euo pipefail

resolved=/var/lib/digitalocean/t3code-resolved.env
info=/var/lib/digitalocean/application.info
[ -f "$resolved" ] || exit 0

# Same character rules as scripts/010-t3code.sh. Versions are one token.
# Ranges may contain spaces and |, and are not written into application.info.
accept_resolved_value() {
  local key="$1" value="$2"
  case "$key" in
    cursor_version_range|grok_version_range)
      grep -Eq '^[A-Za-z0-9._:>=<^| ]*$' <<< "$value"
      ;;
    antigravity_sha256_amd64|antigravity_sha256_arm64)
      grep -Eq '^[a-f0-9]{64}$' <<< "$value"
      ;;
    application_version|node_version|claude_version|codex_version|cursor_version|grok_version|opencode_version|pi_version|fx_version|antigravity_version)
      grep -Eq '^[A-Za-z0-9][A-Za-z0-9._+-]*$' <<< "$value"
      ;;
    *)
      return 1
      ;;
  esac
}

read_resolved_values() {
  local contents="$1" line key value

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    if [[ "$line" != *=* ]]; then
      echo "Invalid resolved entry" >&2
      return 1
    fi

    key="${line%%=*}"
    value="${line#*=}"

    case "$key" in
      application_version|claude_version|codex_version|cursor_version|cursor_version_range|grok_version|grok_version_range|opencode_version|pi_version|fx_version|antigravity_version|antigravity_sha256_amd64|antigravity_sha256_arm64|node_version)
        if ! accept_resolved_value "$key" "$value"; then
          echo "Refusing unusual resolved value for ${key}" >&2
          return 1
        fi
        printf -v "$key" '%s' "$value"
        ;;
      *)
        echo "Unexpected resolved key: $key" >&2
        return 1
        ;;
    esac
  done <<< "$contents"
}

read_resolved_values "$(<"$resolved")" || exit 1

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
