#!/bin/bash
#
# Scripts in this directory are run during the build process.
# each script will be uploaded to /tmp on your build droplet,
# given execute permissions and run.  The cleanup process will
# remove the scripts from your build system after they have run
# if you use the build_image task.
#

set -euo pipefail

PINNED_VERSION="${application_version:?application_version must be set}"
REPO_SERVER_VERSION="mariadb-${PINNED_VERSION}"
MARIADB_DEB_VERSION="1:${PINNED_VERSION}+maria~ubu2404"

# sha256 of https://r.mariadb.com/downloads/mariadb_repo_setup (2026-09-15)
REPO_SETUP_CHECKSUM="b54c87edfe81b9837ef44a4a4f39383dd8df32776e6a18c0743a5d3ece044ac3"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
cd "${tmpdir}"

curl -fsSLO https://r.mariadb.com/downloads/mariadb_repo_setup
echo "${REPO_SETUP_CHECKSUM}  mariadb_repo_setup" | sha256sum -c -
chmod +x mariadb_repo_setup
./mariadb_repo_setup \
  --mariadb-server-version="${REPO_SERVER_VERSION}" \
  --skip-maxscale
rm -f mariadb_repo_setup

cat > /etc/apt/preferences.d/mariadb-pin <<EOF
Package: mariadb-server mariadb-server-core mariadb-client mariadb-common mariadb-client-core
Pin: version ${MARIADB_DEB_VERSION}
Pin-Priority: 1001
EOF

apt -qqy update
apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install \
  mariadb-server="${MARIADB_DEB_VERSION}" \
  mariadb-client="${MARIADB_DEB_VERSION}"

for cmd in mariadb mariadbd; do
  ver_out="$("${cmd}" --version 2>&1)"
  if ! grep -qF "${PINNED_VERSION}" <<<"${ver_out}"; then
    echo "Build sanity check failed: ${cmd} --version does not report ${PINNED_VERSION}: ${ver_out}" >&2
    exit 1
  fi
done

systemctl enable mariadb.service
systemctl start mariadb.service

# Add first-login task
cat >> /root/.bashrc <<EOM
/opt/digitalocean_mariadb/setup_mariadb.sh
EOM
