#!/bin/sh

################################
## PART: Write the application tag
##
## vi: syntax=sh expandtab ts=4

build_date=$(date +%Y-%m-%d)
distro="$(lsb_release -s  -i)"
distro_release="$(lsb_release -s  -r)"
distro_codename="$(lsb_release -s -c)"
distro_arch="$(uname -m)"

# Synapse is the main Marketplace / autoupdate version (apt package).
# Strip Debian revision suffix (e.g. 1.162.0+trixie1 -> 1.162.0).
raw_synapse_version="$(dpkg-query -W -f '${Version}' matrix-synapse-py3 2>/dev/null || true)"
application_version="$(printf '%s\n' "$raw_synapse_version" | sed 's/[+~].*//')"

element_version=""
if [ -L /opt/element ]; then
  element_version="$(basename "$(readlink -f /opt/element)" | sed 's/^element-v//')"
elif [ -d /opt/element ] && [ -f /opt/element/version ]; then
  element_version="$(tr -d '[:space:]' < /opt/element/version)"
fi

mkdir -p /var/lib/digitalocean

cat >> /var/lib/digitalocean/application.info <<EOM
application_name="${application_name}"
build_date="${build_date}"
distro="${distro}"
distro_release="${distro_release}"
distro_codename="${distro_codename}"
distro_arch="${distro_arch}"
application_version="${application_version}"
element_version="${element_version}"
EOM

printf 'Recorded application_version (Synapse)=%s element_version=%s\n' \
  "${application_version}" "${element_version}"
