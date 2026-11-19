#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

: "${application_version:?application_version must be set}"
: "${corretto_version:?corretto_version must be set}"
: "${corretto_md5:?corretto_md5 must be set}"

# Pin Keycloak base image (CVE-2026-114938 / Java4Shell Corretto is fetched below)
sed -i "s|KEYCLOAK_VERSION_PLACEHOLDER|${application_version}|g" /var/digitalocean/Dockerfile

systemctl start docker
systemctl enable docker

CORRETTO_TGZ=/var/digitalocean/corretto.tar.gz
CORRETTO_URL="https://corretto.aws/downloads/resources/${corretto_version}/amazon-corretto-${corretto_version}-linux-x64.tar.gz"

# Fetch patched JDK into the image build context (md5-verified); survives into the snapshot.
curl -fsSL -o "${CORRETTO_TGZ}" "${CORRETTO_URL}"
echo "${corretto_md5}  ${CORRETTO_TGZ}" | md5sum -c -

# Prove the tarball is 21.0.13.1+ on the Ubuntu host (glibc) before baking the snapshot.
VERIFY_DIR=$(mktemp -d)
tar -xzf "${CORRETTO_TGZ}" -C "${VERIFY_DIR}" --strip-components=1
JV=$("${VERIFY_DIR}/bin/java" -version 2>&1 || true)
rm -rf "${VERIFY_DIR}"
case "${JV}" in
  *21.0.13.1*) echo "Corretto verify ok: 21.0.13.1+" ;;
  *)
    echo "regression: Corretto tarball java -version missing 21.0.13.1: ${JV}" >&2
    exit 1
    ;;
esac

# Pre-pull so first-boot docker build can run offline for these layers
docker pull "quay.io/keycloak/keycloak:${application_version}"
docker pull busybox:1.36.1

# Set up nginx
ln -s /etc/nginx/sites-available/keycloak /etc/nginx/sites-enabled/keycloak
unlink /etc/nginx/sites-enabled/default
service nginx restart
