#!/bin/bash
#
# Arch port of common/scripts/020-application-tag.sh (which needs lsb_release).
set -euo pipefail

build_date=$(date +%Y-%m-%d)
. /etc/os-release
distro_arch="$(uname -m)"

sudo mkdir -p /var/lib/digitalocean
cat <<EOM | sudo tee -a /var/lib/digitalocean/application.info >/dev/null
application_name="${application_name}"
build_date="${build_date}"
distro="${NAME}"
distro_release="rolling"
distro_codename="${ID}"
distro_arch="${distro_arch}"
application_version="${application_version}"
EOM

echo "==> Application tag OK"
