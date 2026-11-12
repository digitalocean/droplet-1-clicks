#!/bin/bash
set -euo pipefail

NOD_DIR="${NOD_DIR:-/opt/nod}"
SELF_HOST_DIR="${NOD_DIR}/deployment/self-host"
ENV_FILE="${SELF_HOST_DIR}/.env"

if [ ! -d "${NOD_DIR}/.git" ]; then
  echo "ERROR: Nod checkout not found at ${NOD_DIR}" >&2
  exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: Missing ${ENV_FILE}; cannot update without existing secrets." >&2
  exit 1
fi

TARGET="${1:-}"
cd "${NOD_DIR}"

echo "Fetching latest Nod tags..."
git fetch --tags --force origin

if [ -z "${TARGET}" ]; then
  TARGET=$(git tag -l 'nod-v*' --sort=-v:refname | head -n1 || true)
  if [ -z "${TARGET}" ]; then
    echo "ERROR: Could not determine latest nod-v* tag." >&2
    exit 1
  fi
  echo "Updating to latest tag: ${TARGET}"
else
  echo "Updating to: ${TARGET}"
fi

# Preserve private .env across checkout.
TMP_ENV="$(mktemp)"
cp -a "${ENV_FILE}" "${TMP_ENV}"

git checkout --force "${TARGET}"
cp -a "${TMP_ENV}" "${ENV_FILE}"
chmod 600 "${ENV_FILE}"
rm -f "${TMP_ENV}"

echo "Rebuilding Nod images..."
cd "${SELF_HOST_DIR}"
docker compose --file compose.yaml --env-file .env build

echo "Starting updated stack..."
/opt/restart-nod.sh

echo "Nod updated to ${TARGET}."
echo "Keep a backup of ${ENV_FILE} (especially NOD_VAULT_KEY) before future upgrades."
