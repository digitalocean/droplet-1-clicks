#!/bin/bash
#
# Scripts in this directory are run during the build process.
# each script will be uploaded to /tmp on your build droplet,
# given execute permissions and run.  The cleanup process will
# remove the scripts from your build system after they have run
# if you use the build_image task.
#
# APT autoupdate builds pass application_version="" and expect the
# latest GA from apt (see marketplace autoupdate APT flow / kibana).
# mariadb_repo_setup --mariadb-server-version=latest tracks current GA
# including future majors (e.g. 13.0) on each rebuild.
#

set -e

# sha256 of https://r.mariadb.com/downloads/mariadb_repo_setup (2026-06-30)
REPO_SETUP_CHECKSUM="7325ac7755809ca3312b446bd832542421699298f25b701f9a111bb42df0c7c1"

curl -LsSO https://r.mariadb.com/downloads/mariadb_repo_setup
echo "${REPO_SETUP_CHECKSUM}  mariadb_repo_setup" | sha256sum -c -
chmod +x mariadb_repo_setup

# Empty / Latest / latest → track current GA for Marketplace APT autoupdate.
# A concrete version (e.g. 12.3.3) can still be used for manual rebuilds.
REPO_VERSION="latest"
if [ -n "${application_version}" ] \
  && [ "${application_version}" != "Latest" ] \
  && [ "${application_version}" != "latest" ]; then
  REPO_VERSION="mariadb-${application_version}"
fi

./mariadb_repo_setup \
  --mariadb-server-version="${REPO_VERSION}" \
  --skip-maxscale \
  --skip-tools
rm -f mariadb_repo_setup

apt -qqy update
apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install \
  mariadb-server \
  mariadb-client

chmod +x /opt/digitalocean_mariadb/setup_mariadb.sh
chmod +x /etc/update-motd.d/99-one-click

systemctl enable mariadb.service
systemctl start mariadb.service

# Record installed version for application.info (after 020-application-tag).
INSTALLED_VERSION="$(mysqld --version 2>/dev/null | awk '{print $3}' | cut -d- -f1 || true)"
if [ -z "${INSTALLED_VERSION}" ]; then
  INSTALLED_VERSION="$(mariadb --version 2>/dev/null | sed -n 's/.*Distrib \([0-9.]*\).*/\1/p' || true)"
fi
echo "${INSTALLED_VERSION}" > /var/lib/digitalocean/mariadb_installed_version

# Add first-login task
cat >> /root/.bashrc <<EOM
/opt/digitalocean_mariadb/setup_mariadb.sh
EOM
