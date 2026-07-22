#!/bin/bash
# Print this Droplet's public IPv4 (DigitalOcean metadata), falling back to hostname -I.
set -euo pipefail

meta() {
  curl -fsS --retry 10 --retry-connrefused --max-time 2 "$1" 2>/dev/null || true
}

PUBLIC_IP="$(meta http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)"
if [ -z "${PUBLIC_IP}" ]; then
  PUBLIC_IP="$(hostname -I | awk '{print $1}')"
fi

if [ -z "${PUBLIC_IP}" ]; then
  echo "Unable to determine Droplet public IP" >&2
  exit 1
fi

printf '%s\n' "${PUBLIC_IP}"
