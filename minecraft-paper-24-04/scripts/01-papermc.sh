#!/bin/bash
set -euo pipefail

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

: "${application_version:?application_version must be set (Packer/autoupdate)}"

apt -qqy install wget apt-transport-https gpg curl python3 screen
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
apt -qqy update
apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install temurin-25-jre

groupadd minecraft
useradd --system --shell /usr/sbin/nologin --home /opt/minecraft -g minecraft minecraft

mkdir -p /opt/minecraft

# Marketplace application_version = Paper game version (from Packer/autoupdate).
# Jar build is the newest STABLE Fill build for that game version (not a pinned build id).
read -r PAPER_JAR PAPER_URL < <(PAPER_VERSION="${application_version}" python3 - <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

version = os.environ["PAPER_VERSION"]
ua = "digitalocean-droplet-1-clicks/1.0 (marketplace@digitalocean.com)"
base = f"https://fill.papermc.io/v3/projects/paper/versions/{version}"


def get(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": ua})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def server_download(build: dict) -> tuple[str, str]:
    asset = build["downloads"]["server:default"]
    return asset["name"], asset["url"]


try:
    latest = get(f"{base}/builds/latest")
    if latest.get("channel") == "STABLE":
        name, url = server_download(latest)
        print(name, url)
        sys.exit(0)

    for build_id in get(base).get("builds", []):
        build = get(f"{base}/builds/{build_id}")
        if build.get("channel") == "STABLE":
            name, url = server_download(build)
            print(name, url)
            sys.exit(0)
except (urllib.error.URLError, urllib.error.HTTPError, KeyError, TypeError, json.JSONDecodeError) as exc:
    print(f"Failed to resolve STABLE Paper build for version {version}: {exc}", file=sys.stderr)
    sys.exit(1)

print(f"No STABLE Paper build found for version {version}", file=sys.stderr)
sys.exit(1)
PY
)

if [ -z "${PAPER_JAR}" ] || [ -z "${PAPER_URL}" ]; then
  echo "Failed to resolve Paper download URL from Fill API for version ${application_version}" >&2
  exit 1
fi

wget -q "${PAPER_URL}" -O "/opt/minecraft/${PAPER_JAR}"
ln -sf "${PAPER_JAR}" /opt/minecraft/paper.jar

echo "eula=true" > /opt/minecraft/eula.txt

chown -R minecraft:minecraft /opt/minecraft
