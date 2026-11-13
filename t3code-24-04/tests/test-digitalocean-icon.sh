#!/usr/bin/env bash
# The DigitalOcean Inference provider uses Claude's driver. The web client
# patch must keep injecting one logo script, including after a repeat run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHER="$SCRIPT_DIR/../files/opt/patch-t3code-digitalocean-icon.sh"
ICON_JS="$SCRIPT_DIR/../files/opt/t3code-digitalocean-icon.js"

if [ ! -x "$PATCHER" ]; then
  chmod +x "$PATCHER"
fi

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

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/versions/v1/client"
cat > "$tmp/versions/v1/client/index.html" <<'EOF'
<!doctype html>
<html><body><div id="root"></div></body></html>
EOF

T3_RUNTIME_ROOT="$tmp/versions" T3_DO_ICON_SCRIPT="$ICON_JS" "$PATCHER" >/dev/null
count="$(grep -c 'id="t3code-digitalocean-icon"' "$tmp/versions/v1/client/index.html")"
assert_eq "$count" "1" "icon script is injected once"
grep -q 'digitalocean-inference' "$tmp/versions/v1/client/index.html"
echo "OK: injected script names the inference instance"
grep -q '#0080FF' "$tmp/versions/v1/client/index.html"
echo "OK: injected script uses the DigitalOcean accent"
grep -q 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABz' "$tmp/versions/v1/client/index.html"
echo "OK: injected script embeds the cloud console favicon"
node --check "$ICON_JS"
echo "OK: icon script parses"
if grep -q 'replaceWith\|removeChild' "$ICON_JS"; then
  echo "FAIL: icon script must not remove React-owned nodes"
  FAILURES=$((FAILURES + 1))
else
  echo "OK: icon script leaves React's nodes in place"
fi

T3_RUNTIME_ROOT="$tmp/versions" T3_DO_ICON_SCRIPT="$ICON_JS" "$PATCHER" >/dev/null
count="$(grep -c 'id="t3code-digitalocean-icon"' "$tmp/versions/v1/client/index.html")"
assert_eq "$count" "1" "a second patch does not duplicate the script"

missing="$(mktemp -d)"
if T3_RUNTIME_ROOT="$missing" T3_DO_ICON_SCRIPT="$ICON_JS" "$PATCHER" >/dev/null; then
  echo "OK: missing runtime is skipped"
else
  echo "FAIL: missing runtime should not fail the boot path"
  FAILURES=$((FAILURES + 1))
fi
rmdir "$missing"

if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES check(s) failed."
  exit 1
fi
echo "All DigitalOcean icon checks passed."
