#!/bin/bash
# Extract Logflare runtime.exs from the image used by docker-compose.yml and
# patch it for DigitalOcean Managed Postgres TLS (no client cert PEMs).
# Used at Packer build time and as a first-boot fallback.

set -euo pipefail

COMPOSE_DIR="${1:-/srv/supabase/supabase/docker}"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
ANALYTICS_VOL="${COMPOSE_DIR}/volumes/analytics"
RUNTIME_EXS="${ANALYTICS_VOL}/runtime.exs"
VERSION_FILE="${ANALYTICS_VOL}/logflare_version"

logflare_ssl_ok() {
  local f="$1"
  [ -f "${f}" ] || return 1
  grep -q 'System.get_env("DB_SSL") == "true" do' "${f}" || return 1
  grep -q 'verify: :verify_none' "${f}" || return 1
  # Stock gate must be gone
  ! grep -q 'File.exists?("db-server-ca.pem")' "${f}"
}

patch_logflare_ssl() {
  local f="$1"
  local tmp

  if logflare_ssl_ok "${f}"; then
    echo "Logflare SSL block already patched in ${f}"
    return 0
  fi

  tmp=$(mktemp)
  # Replace the stock PEM-gated DB_SSL block with a DO Managed DB friendly block.
  if ! perl -0pe 's/if\(\s*\n\s*System\.get_env\("DB_SSL"\) == "true" && File\.exists\?\("db-server-ca\.pem"\) &&\s*\n\s*File\.exists\?\("db-client-ca\.pem"\) && File\.exists\?\("db-client-key\.pem"\)\s*\n\) do\n.*?ssl_opts: \[\n.*?\n\s*\]\nend/if System.get_env("DB_SSL") == "true" do\n  # DigitalOcean Managed DB: require TLS without client certificates\n  config :logflare, Logflare.Repo,\n    ssl: true,\n    ssl_opts: [\n      verify: :verify_none,\n      versions: [:"tlsv1.2", :"tlsv1.3"]\n    ]\nend/s' "${f}" > "${tmp}"; then
    rm -f "${tmp}"
    echo "ERROR: perl failed while patching ${f}" >&2
    return 1
  fi

  if ! grep -q 'verify: :verify_none' "${tmp}" || grep -q 'File.exists?("db-server-ca.pem")' "${tmp}"; then
    # Fallback: relax PEM condition and force verify_none
    cp -f "${f}" "${tmp}"
    perl -i -0pe 's/System\.get_env\("DB_SSL"\) == "true" && File\.exists\?\("db-server-ca\.pem"\).*?File\.exists\?\("db-client-key\.pem"\)/System.get_env("DB_SSL") == "true"/s' "${tmp}"
    perl -i -pe 's/verify:\s*:verify_peer,/verify: :verify_none,/' "${tmp}"
    perl -i -pe 's/^\s*cacertfile: "db-server-ca\.pem",\s*$//' "${tmp}"
    perl -i -pe 's/^\s*certfile: "db-client-cert\.pem",\s*$//' "${tmp}"
    perl -i -pe 's/^\s*keyfile: "db-client-key\.pem",\s*$//' "${tmp}"
  fi

  if ! logflare_ssl_ok "${tmp}"; then
    rm -f "${tmp}"
    echo "ERROR: Logflare SSL patch verification failed for ${f}" >&2
    return 1
  fi

  mv -f "${tmp}" "${f}"
  echo "Patched Logflare SSL block in ${f}"
}

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "ERROR: missing ${COMPOSE_FILE}" >&2
  exit 1
fi

# Match top-level analytics service only (not nested depends_on: analytics:).
LOGFLARE_IMAGE=$(awk '
  /^[[:space:]]{2}analytics:[[:space:]]*$/ { f=1; next }
  f && /^[[:space:]]{2}[a-zA-Z0-9_]+:/ { f=0 }
  f && /^[[:space:]]+image:[[:space:]]*/ { print $2; exit }
' "${COMPOSE_FILE}")
LOGFLARE_IMAGE="${LOGFLARE_IMAGE:-supabase/logflare:1.36.1}"
LOGFLARE_VER="${LOGFLARE_IMAGE##*:}"

mkdir -p "${ANALYTICS_VOL}"

# Reuse an already-valid baked file when present
if logflare_ssl_ok "${RUNTIME_EXS}"; then
  if [ ! -f "${VERSION_FILE}" ]; then
    printf '%s\n' "${LOGFLARE_VER}" > "${VERSION_FILE}"
  fi
  echo "Logflare SSL runtime already ready at ${RUNTIME_EXS}"
  exit 0
fi

echo "Preparing Logflare runtime.exs from ${LOGFLARE_IMAGE}"
docker pull "${LOGFLARE_IMAGE}"
lf_cid=$(docker create "${LOGFLARE_IMAGE}")
cleanup() { docker rm -f "${lf_cid}" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker cp "${lf_cid}:/opt/app/rel/logflare/releases/${LOGFLARE_VER}/runtime.exs" "${RUNTIME_EXS}"
cleanup
trap - EXIT

patch_logflare_ssl "${RUNTIME_EXS}"
printf '%s\n' "${LOGFLARE_VER}" > "${VERSION_FILE}"
echo "Logflare SSL runtime ready (${LOGFLARE_VER}) at ${RUNTIME_EXS}"
