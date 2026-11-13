#!/bin/bash
set -euo pipefail

NOD_DIR="${NOD_DIR:-/opt/nod}"
SELF_HOST_DIR="${NOD_DIR}/deployment/self-host"
ENV_FILE="${SELF_HOST_DIR}/.env"

echo "=== Nod service ==="
systemctl is-active nod.service || true
systemctl status nod.service --no-pager -l || true

echo
echo "=== Compose containers ==="
if [ -f "${ENV_FILE}" ]; then
  /opt/nod-compose.sh ps || true
else
  echo "No .env yet (first boot may not have finished)."
fi

echo
echo "=== Access ==="
pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
myip="${pub:-$(hostname -I | awk '{print $1}')}"
echo "URL: https://${myip}"
if [ -f "${ENV_FILE}" ]; then
  token=$(grep -E '^NOD_AUTH_TOKEN=' "${ENV_FILE}" | cut -d= -f2- || true)
  if [ -n "${token}" ]; then
    echo "Access token: ${token}"
  fi
  public_url=$(grep -E '^NOD_PUBLIC_URL=' "${ENV_FILE}" | cut -d= -f2- || true)
  if [ -n "${public_url}" ]; then
    echo "NOD_PUBLIC_URL: ${public_url}"
  fi
fi
