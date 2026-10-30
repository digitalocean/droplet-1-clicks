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
sed -n '/^accept_resolved_value()/,/^}/p; /^read_resolved_values()/,/^}/p; /^version_token_matches()/,/^}/p' "$INSTALLER" > "$parser"
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

read_resolved_values "application_version=1.2.3
node_version=22.23.4
claude_version=2.1.3
antigravity_sha256_amd64=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
cursor_version_range=>=1.0.0 <2.0.0 || ^1.2.0
grok_version_range=^2.0.0"

assert_eq "$application_version" "1.2.3" "valid application version is assigned"
assert_eq "$node_version" "22.23.4" "valid Node version is assigned"
assert_eq "$claude_version" "2.1.3" "valid provider version is assigned"
assert_eq "$antigravity_sha256_amd64" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "valid checksum is assigned"
assert_eq "$cursor_version_range" ">=1.0.0 <2.0.0 || ^1.2.0" "Cursor compatibility range keeps spaces and pipes"
assert_eq "$grok_version_range" "^2.0.0" "Grok compatibility range is assigned"
read_resolved_values "cursor_version_range="
assert_eq "$cursor_version_range" "" "an empty compatibility range is kept"

marker="$(mktemp -u)"
payload="claude_version=\$(touch $marker)"
if read_resolved_values "$payload" >/dev/null 2>&1; then
  echo "FAIL: command substitution text was accepted as a version"
  FAILURES=$((FAILURES + 1))
else
  echo "OK: command substitution text is rejected"
fi
if [ -e "$marker" ]; then
  echo "FAIL: command substitution text was executed"
  rm -f "$marker"
  FAILURES=$((FAILURES + 1))
else
  echo "OK: command substitution text was not executed"
fi

assert_rejected "codex_version=1.0.0 | touch /tmp/x" "a pipe in a version is rejected"
assert_rejected "codex_version=1.0.0 extra" "a space in a version is rejected"
assert_rejected "cursor_version_range=>=1.0.0;id" "a range cannot carry a shell separator"

assert_rejected "application_version=1.2.3
not-an-assignment" "malformed resolved entry is rejected"
assert_rejected "application_version=1.2.3
unexpected_key=value" "unknown resolved key is rejected"

echo
echo "=== Version token matching ==="

assert_version_match() {
  local got="$1" expected="$2" message="$3"
  if version_token_matches "$got" "$expected"; then
    echo "OK: $message"
  else
    echo "FAIL: $message"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_version_mismatch() {
  local got="$1" expected="$2" message="$3"
  if version_token_matches "$got" "$expected"; then
    echo "FAIL: $message"
    FAILURES=$((FAILURES + 1))
  else
    echo "OK: $message"
  fi
}

assert_version_match "1.2.3" "1.2.3" "exact version matches"
assert_version_match "t3 1.2.3" "1.2.3" "version with a leading name matches"
assert_version_match "v1.2.3" "1.2.3" "optional v prefix matches"
assert_version_match "2026.01.15-abcdef" "2026.01.15" "prerelease suffix stays outside the token"
assert_version_mismatch "1.2.30" "1.2.3" "longer patch version is not a substring match"
assert_version_mismatch "v1.2.30" "1.2.3" "v-prefixed longer patch version is not a substring match"
assert_version_mismatch "1.2.3.4" "1.2.3" "extra numeric component is not a match"
assert_version_mismatch "11.2.3" "1.2.3" "longer major version is not a match"

if [ "$FAILURES" -ne 0 ]; then
  echo
  echo "$FAILURES assertion(s) failed"
  exit 1
fi

echo
echo "All assertions passed"
