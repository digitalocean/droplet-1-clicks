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

# Default to latest STABLE build so autoupdate can bump application_version alone
# without pinning a stale build id (e.g. 74 for 26.1.2 does not exist on 26.3).
# Prefer ?channel=STABLE over /builds/latest, which can return ALPHA/BETA.
paper_build="${paper_build:-latest}"
PAPER_UA="User-Agent: digitalocean-droplet-1-clicks/1.0 (marketplace@digitalocean.com)"
PAPER_API="https://fill.papermc.io/v3/projects/paper/versions/${application_version}"

if [ "${paper_build}" = "latest" ]; then
  BUILD_JSON=$(curl -fsSL -H "${PAPER_UA}" "${PAPER_API}/builds?channel=STABLE" | python3 -c '
import json, sys
builds = json.load(sys.stdin)
if not isinstance(builds, list) or not builds:
    print("no STABLE builds returned for this version", file=sys.stderr)
    sys.exit(1)
print(json.dumps(builds[0]))
')
else
  BUILD_JSON=$(curl -fsSL -H "${PAPER_UA}" "${PAPER_API}/builds/${paper_build}")
fi

PAPER_URL=$(printf '%s' "${BUILD_JSON}" | python3 -c "import sys, json; print(json.load(sys.stdin)['downloads']['server:default']['url'])")
RESOLVED_BUILD=$(printf '%s' "${BUILD_JSON}" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
RESOLVED_CHANNEL=$(printf '%s' "${BUILD_JSON}" | python3 -c "import sys, json; print(json.load(sys.stdin).get('channel', ''))")

if [ -z "${PAPER_URL}" ] || [ -z "${RESOLVED_BUILD}" ]; then
  echo "Failed to resolve Paper download URL from Fill API (version=${application_version} build=${paper_build})" >&2
  exit 1
fi

PAPER_JAR="paper-${application_version}-${RESOLVED_BUILD}.jar"
echo "Downloading Paper ${application_version} build ${RESOLVED_BUILD} (${RESOLVED_CHANNEL:-unknown})..."

wget -q "${PAPER_URL}" -O "/opt/minecraft/${PAPER_JAR}"
ln -sf "${PAPER_JAR}" /opt/minecraft/paper.jar

echo "eula=true" > /opt/minecraft/eula.txt

chown -R minecraft:minecraft /opt/minecraft
