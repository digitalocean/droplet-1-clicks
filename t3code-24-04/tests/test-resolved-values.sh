#!/usr/bin/env bash
# Regression tests for parsing the build-time T3 Code version manifest.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER="$SCRIPT_DIR/../scripts/010-t3code.sh"

if [ ! -f "$INSTALLER" ]; then
  echo "FAIL: missing $INSTALLER"
  exit 1
fi

# Load only the parser function; the installer itself performs provisioning.
parser="$(mktemp)"
trap 'rm -f "$parser" "${marker:-}"' EXIT
sed -n '/^read_resolved_values()/,/^}/p' "$INSTALLER" > "$parser"
# shellcheck disable=SC1090
source "$parser"

FAILURES=0

assert_eq() {
  local actual="$1" expected="$2" message="$3"
  if [ "$actual" = "$expected" ]; then
    echo "OK: $message"
  else
    echo "FAIL: $message"
    echo "  expected: $(printf '%q' "$expected")"
    echo "  actual:   $(printf '%q' "$actual")"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_rejected() {
  local contents="$1" message="$2"
  if read_resolved_values "$contents" >/dev/null 2>&1; then
    echo "FAIL: $message"
    FAILURES=$((FAILURES + 1))
  else
    echo "OK: $message"
  fi
}

echo "=== T3 Code resolved-version parsing ==="

marker="$(mktemp -u)"
malicious="\$(touch $marker)"
read_resolved_values "application_version=1.2.3
node_version=22.23.4
claude_version=$malicious
antigravity_sha256_amd64=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
cursor_version_range=>=1.0.0
grok_version_range=^2.0.0"

assert_eq "$application_version" "1.2.3" "valid application version is assigned"
assert_eq "$node_version" "22.23.4" "valid Node version is assigned"
assert_eq "$claude_version" "$malicious" "command substitution text is stored literally"
assert_eq "$antigravity_sha256_amd64" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "valid checksum is assigned"
assert_eq "$cursor_version_range" ">=1.0.0" "Cursor compatibility range is assigned"
assert_eq "$grok_version_range" "^2.0.0" "Grok compatibility range is assigned"

if [ -e "$marker" ]; then
  echo "FAIL: command substitution text was executed"
  rm -f "$marker"
  FAILURES=$((FAILURES + 1))
else
  echo "OK: command substitution text was not executed"
fi

assert_rejected "application_version=1.2.3
not-an-assignment" "malformed resolved entry is rejected"
assert_rejected "application_version=1.2.3
unexpected_key=value" "unknown resolved key is rejected"

if [ "$FAILURES" -ne 0 ]; then
  echo
  echo "$FAILURES assertion(s) failed"
  exit 1
fi

echo
echo "All assertions passed"
