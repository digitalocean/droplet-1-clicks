#!/bin/bash
# CVE-2026-123007: fail if the Discourse app container still serves HTTP/2 (ALPN h2 or h2c on :80).
set -euo pipefail

DISCOURSE_ROOT="${DISCOURSE_ROOT:-/var/discourse}"
ALPN_LIB=/var/lib/digitalocean/nginx2root-alpn-check.sh

# shellcheck source=/dev/null
[ -f "${ALPN_LIB}" ] && source "${ALPN_LIB}"

discourse_app_container() {
  local name
  while IFS= read -r name; do
    [ -n "${name}" ] || continue
    case "${name}" in
      app) printf '%s' "${name}"; return 0 ;;
    esac
  done < <(docker ps --format '{{.Names}}' 2>/dev/null || true)
  return 1
}

wait_for_discourse_container() {
  local i name
  for i in $(seq 1 60); do
    if name=$(discourse_app_container); then
      printf '%s' "${name}"
      return 0
    fi
    sleep 5
  done
  echo "verify: Discourse app container is not running" >&2
  return 1
}

discourse_exec() {
  local container="${1:?container}"
  shift
  docker exec "${container}" "$@"
}

nginx_loaded_config_in_container() {
  local container="${1:?container}"
  local out
  out=$(discourse_exec "${container}" nginx -T 2>&1 || true)
  printf '%s' "${out}"
}

nginx_config_advertises_http2() {
  local cfg="${1:?config dump}"
  local active
  active=$(grep -v '^[[:space:]]*#' <<<"${cfg}" || true)
  if grep -E '^[[:space:]]*listen[^;]*http2' <<<"${active}" >/dev/null; then
    return 0
  fi
  if grep -E '^[[:space:]]*http2[[:space:]]+on;' <<<"${active}" >/dev/null; then
    return 0
  fi
  return 1
}

curl_h2c_prior_knowledge() {
  local url="${1:?url}"
  local ver
  ver=$(curl -sS -o /dev/null -w '%{http_version}' --connect-timeout 10 --max-time 20 \
    --http2-prior-knowledge "${url}" 2>/dev/null || echo "0")
  case "${ver}" in
    2 | 2.0) return 0 ;;
    *) return 1 ;;
  esac
}

validate_discourse_hostname_in_app_yml() {
  local app_yml="${DISCOURSE_ROOT}/containers/app.yml"
  [ -f "${app_yml}" ] || return 0
  python3 - "${app_yml}" <<'PY'
import re
import sys
import yaml

path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f) or {}
host = str((data.get("env") or {}).get("DISCOURSE_HOSTNAME", "")).strip()
if not host:
    sys.exit(0)
if len(host) > 253:
    print(f"verify: DISCOURSE_HOSTNAME too long ({len(host)} chars)", file=sys.stderr)
    sys.exit(1)
if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?", host):
    print(f"verify: DISCOURSE_HOSTNAME has invalid characters: {host!r}", file=sys.stderr)
    sys.exit(1)
for width in range(len(host) // 2, 7, -1):
    chunk = host[:width]
    rest = host[width:]
    if chunk in rest and chunk.count(".") >= 1:
        print(
            f"verify: DISCOURSE_HOSTNAME looks duplicated (our wrapper does not write app.yml): {host!r}",
            file=sys.stderr,
        )
        sys.exit(1)
PY
}

main() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "verify: docker missing" >&2
    exit 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "verify: curl missing" >&2
    exit 1
  fi

  validate_discourse_hostname_in_app_yml

  local container cfg
  container=$(wait_for_discourse_container)

  cfg=$(nginx_loaded_config_in_container "${container}")
  if nginx_config_advertises_http2 "${cfg}"; then
    echo "verify: container nginx -T still advertises HTTP/2 (listen http2 or http2 on)" >&2
    exit 1
  fi

  if curl_h2c_prior_knowledge "http://127.0.0.1:80/"; then
    echo "verify: port 80 negotiates cleartext HTTP/2 (h2c prior knowledge)" >&2
    exit 1
  fi

  if [ -f "${ALPN_LIB}" ]; then
    local host
    host=$(
      python3 - "${DISCOURSE_ROOT}/containers/app.yml" <<'PY'
import sys
import yaml

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}
print((data.get("env") or {}).get("DISCOURSE_HOSTNAME", "localhost"))
PY
    )
    assert_alpn_no_h2 "discourse-container-443" "127.0.0.1" "443" "${host}"
  fi

  echo "discourse container nginx2root verify ok (no h2c :80, no ALPN h2 :443)"
}

main "$@"