#!/bin/bash

# This script runs on first boot of a newly created Droplet
# to prepare the system for PMM3

hostnamectl set-hostname pmm3

systemctl enable docker
systemctl start docker
docker start pmm-server || true

# CVE-2026-123007: ensure in-container nginx does not advertise HTTP/2.
if [ -x /var/lib/digitalocean/pmm-mitigate-nginx2root.sh ]; then
  /var/lib/digitalocean/pmm-mitigate-nginx2root.sh
fi

if [ -f /var/lib/digitalocean/nginx2root-alpn-check.sh ]; then
  # shellcheck source=/dev/null
  . /var/lib/digitalocean/nginx2root-alpn-check.sh
  assert_alpn_no_h2 "PMM Server" 127.0.0.1 443
fi