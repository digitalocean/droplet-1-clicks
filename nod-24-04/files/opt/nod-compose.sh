#!/bin/bash
set -euo pipefail

# Shared docker compose wrapper for Nod self-host helpers.
NOD_DIR="${NOD_DIR:-/opt/nod}"
SELF_HOST_DIR="${NOD_DIR}/deployment/self-host"
ENV_FILE="${SELF_HOST_DIR}/.env"

if [ ! -d "${SELF_HOST_DIR}" ]; then
  echo "ERROR: Nod self-host directory not found at ${SELF_HOST_DIR}" >&2
  exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: Missing ${ENV_FILE}. Run first-boot setup or: cd ${SELF_HOST_DIR} && sh setup.sh" >&2
  exit 1
fi

cd "${SELF_HOST_DIR}"
exec docker compose --file compose.yaml --env-file .env "$@"
