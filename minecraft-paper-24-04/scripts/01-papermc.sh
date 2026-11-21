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
# One Fill list call (?channel=STABLE) — avoids N per-build requests when latest is non-STABLE.
read -r PAPER_JAR PAPER_URL < <(PAPER_VERSION="${application_version}" python3 - <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

version = os.environ["PAPER_VERSION"]
ua = "digitalocean-droplet-1-clicks/1.0 (marketplace@digitalocean.com)"
base = f"https://fill.papermc.io/v3/projects/paper/versions/{version}"


def get(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": ua})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def server_download(build: dict):
    """Return (name, url) if build has a usable server:default asset; else None."""
    if not isinstance(build, dict):
        return None
    downloads = build.get("downloads")
    if not isinstance(downloads, dict):
        return None
    asset = downloads.get("server:default")
    if not isinstance(asset, dict):
        return None
    name, url = asset.get("name"), asset.get("url")
    if not name or not url:
        return None
    return name, url


def newest_stable(builds):
    """Pick highest numeric build id among usable STABLE (or unfiltered) build objects."""
    if not isinstance(builds, list):
        return None
    best = None
    best_id = None
    for build in builds:
        if not isinstance(build, dict):
            continue
        bid = build.get("id")
        if not isinstance(bid, int):
            continue
        if server_download(build) is None:
            continue
        if best_id is None or bid > best_id:
            best, best_id = build, bid
    return best


try:
    # Prefer the cheap latest endpoint when it is already STABLE.
    latest = get(f"{base}/builds/latest")
    asset = server_download(latest) if latest.get("channel") == "STABLE" else None
    if asset:
        print(asset[0], asset[1])
        sys.exit(0)

    # Otherwise one filtered list — select max id (do not assume API sort order).
    builds = get(f"{base}/builds?channel=STABLE")
    chosen = newest_stable(builds)
    if chosen is None:
        print(f"No STABLE Paper build found for version {version}", file=sys.stderr)
        sys.exit(1)
    name, url = server_download(chosen)
    print(name, url)
except (urllib.error.URLError, urllib.error.HTTPError, KeyError, TypeError, json.JSONDecodeError) as exc:
    print(f"Failed to resolve STABLE Paper build for version {version}: {exc}", file=sys.stderr)
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
