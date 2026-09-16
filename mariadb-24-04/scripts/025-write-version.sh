#!/bin/bash
#
# Marketplace APT autoupdate leaves application_version empty/Latest.
# Replace it with the MariaDB version actually installed on the image.
#

set -e

version_file="/var/lib/digitalocean/mariadb_installed_version"
info_file="/var/lib/digitalocean/application.info"

if [ ! -f "${version_file}" ]; then
  echo "missing ${version_file}" >&2
  exit 1
fi

installed_version="$(tr -d '[:space:]' < "${version_file}")"
if [ -z "${installed_version}" ]; then
  echo "empty installed MariaDB version" >&2
  exit 1
fi

if [ -f "${info_file}" ] && grep -q '^application_version=' "${info_file}"; then
  sed -i "s/^application_version=.*/application_version=\"${installed_version}\"/" "${info_file}"
else
  echo "application_version=\"${installed_version}\"" >> "${info_file}"
fi

echo "application_version set to ${installed_version}"
