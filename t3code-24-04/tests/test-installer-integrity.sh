#!/usr/bin/env bash
# Remote installers must be checksummed, and t3 commands must not be built
# by joining resolved values into a shell string.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER="$SCRIPT_DIR/../scripts/010-t3code.sh"
REMOTE="$SCRIPT_DIR/../files/usr/local/bin/run-remote-installer"

FAILURES=0
fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}
ok() {
  echo "OK: $1"
}

echo "=== Installer pins ==="

if grep -n 'codex/raw/main\|/main/scripts/install/install.sh' "$INSTALLER"; then
  fail "Codex installer still tracks main"
else
  ok "Codex installer does not track main"
fi

if grep -n 'bash -lc' "$INSTALLER"; then
  fail "provisioner still joins a command into bash -lc"
else
  ok "provisioner does not join commands into bash -lc"
fi

if grep -nE 'curl[^|]*\|[[:space:]]*(sh|bash|tar)' "$INSTALLER"; then
  fail "provisioner still pipes a download into a shell or tar"
else
  ok "provisioner does not pipe downloads into a shell or tar"
fi

pins=0
while IFS= read -r line; do
  pins=$((pins + 1))
done < <(grep -E '^[A-Z0-9_]+_SHA256=[a-f0-9]{64}$' "$INSTALLER")
if [ "$pins" -ge 9 ]; then
  ok "installer SHA-256 pins are present ($pins)"
else
  fail "expected at least 9 installer SHA-256 pins, found $pins"
fi

missing=0
while IFS= read -r line; do
  case "$line" in
    *--sha256*) ;;
    *)
      echo "$line"
      missing=$((missing + 1))
      ;;
  esac
done < <(grep -n 'run-remote-installer' "$INSTALLER" | grep -v 'chmod')
if [ "$missing" -eq 0 ]; then
  ok "every remote installer call passes --sha256"
else
  fail "$missing remote installer call(s) omit --sha256"
fi

echo
echo "=== run-remote-installer ==="

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
cat > "$workdir/installer.sh" <<'EOF'
#!/bin/bash
printf 'ran:%s\n' "$1"
EOF
expected="$(sha256sum "$workdir/installer.sh" | awk '{print $1}')"
output="$(bash "$REMOTE" --sha256 "$expected" "file://${workdir}/installer.sh" bash hello)"
if [ "$output" = "ran:hello" ]; then
  ok "matching digest executes the installer"
else
  fail "matching digest did not execute the installer"
  echo "  actual: $(printf '%q' "$output")"
fi

marker="$(mktemp -u)"
cat > "$workdir/bad.sh" <<EOF
#!/bin/bash
touch "$marker"
EOF
if bash "$REMOTE" --sha256 "$expected" "file://${workdir}/bad.sh" bash >/dev/null 2>&1; then
  fail "mismatched digest was accepted"
else
  ok "mismatched digest is rejected"
fi
if [ -e "$marker" ]; then
  fail "mismatched installer was executed"
  rm -f "$marker"
else
  ok "mismatched installer was not executed"
fi

if bash "$REMOTE" "file://${workdir}/installer.sh" bash >/dev/null 2>&1; then
  fail "installer ran without a digest"
else
  ok "a missing digest is rejected"
fi

echo
echo "=== command arguments ==="

parser="$(mktemp)"
sed -n '/^run_as_t3()/,/^}/p' "$INSTALLER" > "$parser"
# shellcheck disable=SC1090
source "$parser"
rm -f "$parser"

runuser() {
  shift 3
  "$@"
}

home="$(mktemp -d)"
T3_USER=t3
T3_HOME="$home"
T3_PATH="/usr/bin:/bin"
marker="$(mktemp -u)"
payload="a b | touch ${marker}"
got="$(run_as_t3 -- printf '%s' "$payload")"
if [ "$got" = "$payload" ] && [ ! -e "$marker" ]; then
  ok "a payload with spaces and a pipe stays one argument"
else
  fail "payload was parsed as a shell command"
  echo "  actual: $(printf '%q' "$got")"
fi

got="$(run_as_t3 --env "FOO=${payload}" -- bash -c 'printf %s "$FOO"')"
if [ "$got" = "$payload" ] && [ ! -e "$marker" ]; then
  ok "an environment value with spaces and a pipe is not parsed"
else
  fail "environment value was parsed as a shell command"
  echo "  actual: $(printf '%q' "$got")"
fi

if run_as_t3 --env $'FOO=bad\nbar' -- true >/dev/null 2>&1; then
  fail "a newline in an environment value was accepted"
else
  ok "a newline in an environment value is rejected"
fi

rm -rf "$home"
if [ "$FAILURES" -ne 0 ]; then
  echo
  echo "$FAILURES check(s) failed."
  exit 1
fi
echo
echo "All installer integrity checks passed."
