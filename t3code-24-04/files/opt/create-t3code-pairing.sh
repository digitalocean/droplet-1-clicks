#!/bin/bash
# Mint a 24-hour pairing link for the public HTTPS origin.
# Usage: /opt/create-t3code-pairing.sh [https://host]
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

pub=$(curl -fsS --retry 3 --retry-connrefused --max-time 3 \
  http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null || true)
priv=$(hostname -I | awk '{print $1}')
default_host="${pub:-$priv}"
BASE_URL="${1:-https://${default_host}}"

if ! systemctl is-active --quiet t3code; then
  systemctl start t3code
fi

ready=0
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:3773/" || true)
  case "$code" in
    ""|000) sleep 2 ;;
    *) ready=1; break ;;
  esac
done
if [ "$ready" != "1" ]; then
  echo "T3 Code did not answer on 127.0.0.1:3773." >&2
  exit 1
fi

umask 077
pair_err="$(mktemp)"
chmod 600 "$pair_err"
if ! runuser -u t3 -- env HOME=/home/t3 T3CODE_HOME=/home/t3/.t3 \
  /usr/local/bin/t3 auth pairing create \
    --base-url "$BASE_URL" \
    --ttl 24h \
    --label "droplet" \
  > /root/.t3code-pairing.txt 2>"$pair_err"; then
  rm -f "$pair_err" /root/.t3code-pairing.txt
  echo "Failed to create a pairing link." >&2
  exit 1
fi
rm -f "$pair_err"
chmod 600 /root/.t3code-pairing.txt
echo "Pairing link saved to /root/.t3code-pairing.txt (valid for 24 hours)."
