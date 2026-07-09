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

PAPER_URL=$(curl -fsSL -H "User-Agent: digitalocean-droplet-1-clicks/1.0 (marketplace@digitalocean.com)" \
  "https://fill.papermc.io/v3/projects/paper/versions/26.1.2/builds/74" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['downloads']['server:default']['url'])")

if [ -z "${PAPER_URL}" ]; then
  echo "Failed to resolve Paper download URL from Fill API" >&2
  exit 1
fi

wget -q "${PAPER_URL}" -O /opt/minecraft/paper-26.1.2-74.jar

echo "eula=true" > /opt/minecraft/eula.txt

chown -R minecraft:minecraft /opt/minecraft
