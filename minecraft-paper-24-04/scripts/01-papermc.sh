#!/bin/bash
set -euo pipefail

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

apt -qqy install wget apt-transport-https gpg curl python3 screen
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
apt -qqy update
apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install temurin-25-jre

groupadd minecraft
useradd --system --shell /usr/sbin/nologin --home /opt/minecraft -g minecraft minecraft

mkdir -p /opt/minecraft

# Resolve a Paper build for application_version. Autoupdate only passes
# application_version; use builds/latest unless a concrete paper_build is set.
PAPER_UA="User-Agent: digitalocean-droplet-1-clicks/1.0 (marketplace@digitalocean.com)"
if [ -n "${paper_build:-}" ] && [ "${paper_build}" != "latest" ]; then
  BUILD_PATH="builds/${paper_build}"
else
  BUILD_PATH="builds/latest"
fi

BUILD_META=$(curl -fsSL -H "${PAPER_UA}" \
  "https://fill.papermc.io/v3/projects/paper/versions/${application_version}/${BUILD_PATH}" \
  | python3 -c "import sys, json; d=json.load(sys.stdin); dl=d['downloads']['server:default']; print(d['id']); print(dl['url']); print(dl['name'])")

PAPER_BUILD=$(printf '%s\n' "${BUILD_META}" | sed -n '1p')
PAPER_URL=$(printf '%s\n' "${BUILD_META}" | sed -n '2p')
PAPER_JAR=$(printf '%s\n' "${BUILD_META}" | sed -n '3p')

if [ -z "${PAPER_BUILD}" ] || [ -z "${PAPER_URL}" ] || [ -z "${PAPER_JAR}" ]; then
  echo "Failed to resolve Paper download URL from Fill API for version ${application_version}" >&2
  exit 1
fi

echo "Resolved Paper ${application_version} build ${PAPER_BUILD} -> ${PAPER_JAR}"

wget -q "${PAPER_URL}" -O "/opt/minecraft/${PAPER_JAR}"
ln -sf "${PAPER_JAR}" /opt/minecraft/paper.jar

echo "eula=true" > /opt/minecraft/eula.txt

chown -R minecraft:minecraft /opt/minecraft
