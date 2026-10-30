#!/bin/bash
# Inject the DigitalOcean logo script into each installed T3 Code web client.
# T3 picks provider icons from the driver, and this instance uses claudeAgent.
set -euo pipefail

SCRIPT_SRC="${T3_DO_ICON_SCRIPT:-/opt/t3code-digitalocean-icon.js}"
RUNTIME_ROOT="${T3_RUNTIME_ROOT:-/home/t3/.t3/runtime/versions}"
MARKER='id="t3code-digitalocean-icon"'

if [ ! -f "$SCRIPT_SRC" ]; then
  echo "DigitalOcean icon script missing: $SCRIPT_SRC" >&2
  exit 1
fi

if [ ! -d "$RUNTIME_ROOT" ]; then
  echo "T3 Code runtime not installed yet; skipping DigitalOcean icon." >&2
  exit 0
fi

python3 - "$SCRIPT_SRC" "$RUNTIME_ROOT" "$MARKER" <<'PY'
import pathlib
import sys

script_path, runtime_root, marker = sys.argv[1:]
script = pathlib.Path(script_path).read_text()
if "</script>" in script.lower():
    raise SystemExit("icon script must not contain a script end tag")

block = f'<script {marker}>\n{script}</script>\n'
patched = 0
for index in pathlib.Path(runtime_root).rglob("client/index.html"):
    html = index.read_text()
    start = html.find("<script " + marker)
    if start == -1:
        start = html.find("<script " + marker.replace('"', "'"))
    if start != -1:
        end = html.find("</script>", start)
        if end == -1:
            raise SystemExit(f"unclosed icon script in {index}")
        html = html[:start] + html[end + len("</script>") :]
    body = html.lower().rfind("</body>")
    if body == -1:
        raise SystemExit(f"{index} has no body end tag")
    html = html[:body] + block + html[body:]
    index.write_text(html)
    patched += 1

if patched == 0:
    print("No T3 Code client/index.html found; DigitalOcean icon not injected.", file=sys.stderr)
else:
    print(f"DigitalOcean icon injected into {patched} T3 Code client(s).")
PY
