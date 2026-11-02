#!/bin/bash
# Update Apache Superset by rebuilding the local image from an official tag.
#
# Usage:
#   /opt/update-superset.sh              # install latest stable tag from Docker Hub
#   /opt/update-superset.sh latest       # same as no args
#   /opt/update-superset.sh 6.1.0        # install that exact version
#   /opt/update-superset.sh --list       # print recent stable tags and exit
#   /opt/update-superset.sh --rollback   # reinstall previous version
#
# Marketplace images ship a digest-pinned 6.1.0 build. This helper moves the
# Droplet to apache/superset:<version>, reinstalls psycopg2-binary and
# Flask-Caching, runs metadata migrations, and restarts the service.

set -euo pipefail

# shellcheck source=/dev/null
source /opt/superset/lib.sh

VERSION_FILE=/etc/superset/version
PREV_VERSION_FILE=/etc/superset/version.previous
IMAGE_REF_FILE=/etc/superset/image-ref
HUB_TAGS_URL='https://hub.docker.com/v2/repositories/apache/superset/tags?page_size=100&ordering=-last_updated'
LIST_COUNT=15

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo $0 ${*:-}" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: /opt/update-superset.sh [version|--list|--rollback]

  (no args) / latest   Install the latest stable apache/superset tag
  6.1.0                Install that exact version
  --list               Print current, latest, and recent tags, then exit
  --rollback           Reinstall the previous version (if recorded)

Upgrades rebuild /opt/superset into superset-local:<version>, run
`superset db upgrade`, and restart the service. Back up important dashboards
before major upgrades.
EOF
}

current_version() {
  if [[ -s "$VERSION_FILE" ]]; then
    tr -d '[:space:]' <"$VERSION_FILE"
    return 0
  fi
  if [[ -s "$IMAGE_REF_FILE" ]]; then
    local ref
    ref="$(tr -d '[:space:]' <"$IMAGE_REF_FILE")"
    case "$ref" in
      *:*)
        printf '%s\n' "${ref##*:}"
        return 0
        ;;
    esac
  fi
  if [[ -f /var/lib/digitalocean/application.info ]]; then
    sed -n 's/^application_version="\(.*\)"$/\1/p' /var/lib/digitalocean/application.info | tail -n1
    return 0
  fi
  return 1
}

normalize_version() {
  local v="${1#v}"
  case "$v" in
    ''|Latest|LATEST|latest) printf '%s' "latest" ;;
    *) printf '%s' "$v" ;;
  esac
}

hub_tag_names() {
  curl -fsS --max-time 30 "$HUB_TAGS_URL" \
    | python3 -c '
import json, sys, re
data = json.load(sys.stdin)
pat = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
seen = []
for row in data.get("results") or []:
    name = row.get("name") or ""
    if pat.match(name) and name not in seen:
        seen.append(name)
for name in seen:
    print(name)
'
}

latest_stable_tag() {
  hub_tag_names | head -n1
}

version_on_hub() {
  local ver="$1"
  hub_tag_names | grep -Fx "$ver" >/dev/null
}

print_version_list() {
  local current="$1" latest="$2" ver
  echo "Currently installed: ${current:-unknown}"
  echo "Latest on Docker Hub: ${latest:-unknown}"
  echo
  echo "Recent stable apache/superset tags:"
  while IFS= read -r ver; do
    [[ -n "$ver" ]] || continue
    local mark=""
    [[ "$ver" == "$latest" ]] && mark="${mark} latest"
    [[ "$ver" == "$current" ]] && mark="${mark} current"
    printf "  %-12s%s\n" "$ver" "${mark:+ (${mark# })}"
  done < <(hub_tag_names | head -n "$LIST_COUNT")
}

resolve_target() {
  local target="$1" latest
  if [[ "$target" == "latest" ]]; then
    latest="$(latest_stable_tag || true)"
    if [[ -z "$latest" ]]; then
      echo "Error: could not determine latest stable tag from Docker Hub" >&2
      exit 1
    fi
    printf '%s' "$latest"
    return 0
  fi
  printf '%s' "$target"
}

write_update_dockerfile() {
  local version="$1" out="$2"
  cat >"$out" <<EOF
FROM apache/superset:${version}

USER root

# Lean official images omit a Postgres driver; Flask-Caching is required at runtime.
RUN . /app/.venv/bin/activate && \\
    uv pip install --no-cache \\
      "psycopg2-binary" \\
      "Flask-Caching"

USER superset

CMD ["/app/docker/entrypoints/run-server.sh"]
EOF
}

record_version() {
  local version="$1" before="$2"
  umask 022
  if [[ -n "$before" && "$before" != "$version" ]]; then
    printf '%s\n' "$before" >"$PREV_VERSION_FILE"
  fi
  printf '%s\n' "$version" >"$VERSION_FILE"
  printf '%s\n' "superset-local:${version}" >"$IMAGE_REF_FILE"

  if [[ -f /var/lib/digitalocean/application.info ]]; then
    if grep -q '^application_version=' /var/lib/digitalocean/application.info; then
      sed -i "s/^application_version=.*/application_version=\"${version}\"/" \
        /var/lib/digitalocean/application.info
    else
      echo "application_version=\"${version}\"" >>/var/lib/digitalocean/application.info
    fi
  fi
}

wait_healthy() {
  local i
  for i in $(seq 1 60); do
    if curl -fsS --max-time 3 http://127.0.0.1:8088/health >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

MODE="update"
TARGET=""
BEFORE="$(current_version || true)"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --list|-l)
    if ! latest="$(latest_stable_tag)"; then
      echo "Error: could not fetch tags from Docker Hub" >&2
      exit 1
    fi
    print_version_list "${BEFORE:-unknown}" "$latest"
    exit 0
    ;;
  --rollback|-r)
    MODE="rollback"
    if [[ ! -s "$PREV_VERSION_FILE" ]]; then
      echo "Error: no previous version recorded in ${PREV_VERSION_FILE}" >&2
      echo "Install a specific version instead, e.g.: sudo /opt/update-superset.sh 6.1.0" >&2
      exit 1
    fi
    TARGET="$(normalize_version "$(tr -d '[:space:]' <"$PREV_VERSION_FILE")")"
    ;;
  *)
    TARGET="$(normalize_version "${1:-latest}")"
    ;;
esac

TARGET="$(resolve_target "$TARGET")"

if ! version_on_hub "$TARGET"; then
  # Tag might be valid but older than the first Hub page; try a pull probe.
  if ! docker pull "apache/superset:${TARGET}" >/dev/null 2>&1; then
    echo "Error: apache/superset:${TARGET} was not found on Docker Hub" >&2
    echo "List tags with: sudo /opt/update-superset.sh --list" >&2
    exit 1
  fi
fi

if [[ -n "$BEFORE" && "$BEFORE" == "$TARGET" && "$MODE" != "rollback" ]]; then
  echo "Already on Apache Superset ${TARGET}. Rebuilding local image and restarting..."
fi

if [[ ! -s /etc/superset/superset.env ]]; then
  echo "Superset is not initialized. Run /var/lib/cloud/scripts/per-instance/001_onboot" >&2
  exit 1
fi

echo "Updating Apache Superset to ${TARGET} (was: ${BEFORE:-unknown})..."

DOCKERFILE="$(mktemp)"
trap 'rm -f "$DOCKERFILE"' EXIT
write_update_dockerfile "$TARGET" "$DOCKERFILE"

NEW_IMAGE="superset-local:${TARGET}"
echo "Building ${NEW_IMAGE} from apache/superset:${TARGET}..."
docker pull "apache/superset:${TARGET}"
docker build --platform linux/amd64 -t "$NEW_IMAGE" -f "$DOCKERFILE" /opt/superset

echo "Stopping Superset..."
systemctl stop superset || true
docker rm -f superset >/dev/null 2>&1 || true

record_version "$TARGET" "${BEFORE:-}"

echo "Applying metadata migrations..."
if ! superset_run superset db upgrade; then
  echo "Error: metadata migration failed. Image ref is ${NEW_IMAGE}; service is stopped." >&2
  echo "Check logs, then: systemctl start superset" >&2
  echo "Or rollback: sudo /opt/update-superset.sh --rollback" >&2
  exit 1
fi

echo "Starting Superset ${TARGET}..."
systemctl start superset

if wait_healthy && systemctl is-active --quiet superset; then
  if [[ "$MODE" == "rollback" ]]; then
    echo "Apache Superset rolled back to ${TARGET}."
  else
    echo "Apache Superset updated to ${TARGET}."
  fi
  if [[ -n "${BEFORE:-}" && "$BEFORE" != "$TARGET" ]]; then
    echo "Rollback (if needed): sudo /opt/update-superset.sh --rollback"
  fi
else
  echo "Error: Superset did not become healthy after update." >&2
  echo "Check: journalctl -u superset -xe && docker logs superset" >&2
  exit 1
fi
