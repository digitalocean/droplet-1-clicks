#!/bin/bash
set -euo pipefail

if [ -x /var/lib/digitalocean/dokku-mitigate-nginx2root.sh ]; then
  /var/lib/digitalocean/dokku-mitigate-nginx2root.sh
fi