#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${SKILL_DIR}/../.." && pwd)"

echo "running tests for create-1-click-builder..."

"${REPO_ROOT}/scripts/validate-all.sh" "${SKILL_DIR}"

AGENT_REF="${SKILL_DIR}/references/DROPLET_1_CLICK_AGENT.md"
for phrase in \
  "Requirements and best practices" \
  "failed 5 times in a row" \
  "You may only work within the directory"; do
  grep -qF "${phrase}" "${AGENT_REF}" || {
    echo "error: DROPLET_1_CLICK_AGENT.md missing phrase: ${phrase}" >&2
    exit 1
  }
done

if ! grep -qE 'onboard-1-click-autoupdate' "${SKILL_DIR}/SKILL.md" \
  && ! grep -qE 'onboard-1-click-autoupdate' "${SKILL_DIR}/README.md"; then
  echo "error: SKILL.md or README.md must mention onboard-1-click-autoupdate" >&2
  exit 1
fi

if grep -qE 'update-1-click-image.*new listing|new listing.*update-1-click-image' \
  "${SKILL_DIR}/SKILL.md" 2>/dev/null; then
  echo "error: SKILL.md must not hand off to update-1-click-image for new listings" >&2
  exit 1
fi

for phrase in 'git fetch origin' 'git checkout master' 'git pull origin master' 'git checkout -b'; do
  grep -qF "${phrase}" "${SKILL_DIR}/SKILL.md" || {
    echo "error: SKILL.md must document branch workflow (missing: ${phrase})" >&2
    exit 1
  }
done

resolve_links() {
  local file="$1"
  python3 - "${file}" "${SKILL_DIR}" <<'PY'
import re, sys, os
path, root = sys.argv[1], sys.argv[2]
text = open(path).read()
base = os.path.dirname(path)
for m in re.finditer(r'\[[^\]]*\]\(([^)]+)\)', text):
    target = m.group(1).strip()
    if target.startswith(("http://", "https://", "#", "mailto:")):
        continue
    resolved = os.path.normpath(os.path.join(base, target))
    if not os.path.exists(resolved):
        print(f"error: broken link in {path}: {target}", file=sys.stderr)
        sys.exit(1)
PY
}

resolve_links "${SKILL_DIR}/SKILL.md"
resolve_links "${SKILL_DIR}/README.md"

echo "tests passed"
