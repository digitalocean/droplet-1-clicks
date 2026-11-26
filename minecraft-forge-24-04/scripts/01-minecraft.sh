#!/bin/bash
set -euo pipefail

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

groupadd minecraft
useradd --system --shell /usr/sbin/nologin --home /opt/minecraft -g minecraft minecraft

mkdir -p /opt/minecraft/mods

# Modern Forge (1.17+) installs into the current working directory and
# downloads the matching Mojang server itself. Do not pre-seed server.jar.
FORGE_VERSION="${application_version}"
FORGE_INSTALLER="forge-${FORGE_VERSION}-installer.jar"
FORGE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_VERSION}/${FORGE_INSTALLER}"

wget -q "${FORGE_URL}" -O "/opt/minecraft/${FORGE_INSTALLER}"

echo "eula=true" > /opt/minecraft/eula.txt
chown -R minecraft:minecraft /opt/minecraft

# Installer writes libraries/, run.sh, and user_jvm_args.txt relative to CWD.
# Running it outside /opt/minecraft leaves a vanilla server.jar and an unused
# installer — the Harbor QA failure mode for this image.
cd /opt/minecraft
sudo -u minecraft /usr/bin/java -jar "${FORGE_INSTALLER}" --installServer

if [ ! -f /opt/minecraft/run.sh ] || [ ! -d /opt/minecraft/libraries/net/minecraftforge ]; then
  echo "Forge server install failed: run.sh or Forge libraries missing" >&2
  exit 1
fi

chmod +x /opt/minecraft/run.sh

# Installer may rewrite eula.txt; keep the 1-Click pre-accepted.
echo "eula=true" > /opt/minecraft/eula.txt

rm -f "/opt/minecraft/${FORGE_INSTALLER}" /opt/minecraft/installer.log
chown -R minecraft:minecraft /opt/minecraft

ufw limit ssh
ufw allow 25565/tcp
ufw allow 25565/udp

ufw --force enable
