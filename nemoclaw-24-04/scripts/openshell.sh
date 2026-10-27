#!/bin/sh
set -e

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update -y

sudo apt install docker-ce docker-ce-cli containerd.io -y

# OpenShell is installed after NemoClaw is checked out, pinned to the version
# that release supports. Do not curl OpenShell main — floating releases (e.g.
# 0.1.3) break onboard, and a missing /usr/bin package after a partial remove
# also fails package-managed gateway adoption.

# Install latest Node 24.x via nvm (not floating Current "node").
# CVE-2026-111497 (Brotli RCE; trackers VULN-5695 / VULN-5716): require maj 24
# at or above NODE_CVE_MIN. Raise NODE_CVE_MIN for future Node CVEs; never
# remove the fail-closed check. Do not switch back to "nvm install node".
# (Also fixed upstream in 22.23.4 / 26.12.1; this image stays on 24.x.)
# OpenClaw / auto-update need >=24.16; NemoClaw itself only needs >=22.19.
export NODE_CVE_MIN=24.22.1

curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

{
  echo 'export NVM_DIR="$HOME/.nvm"'
  echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
} >> ~/.bashrc

nvm install 24
nvm use 24
nvm alias default 24

# Fail the Packer build if nvm did not land a patched 24.x.
node -e '
  function ge(a, b) {
    const pa = String(a).split(".").map((x) => parseInt(x, 10) || 0);
    const pb = String(b).split(".").map((x) => parseInt(x, 10) || 0);
    for (let i = 0; i < 3; i++) {
      if ((pa[i] || 0) > (pb[i] || 0)) return true;
      if ((pa[i] || 0) < (pb[i] || 0)) return false;
    }
    return true;
  }
  const min = process.env.NODE_CVE_MIN;
  if (!min || !/^\d+\.\d+\.\d+$/.test(min)) {
    console.error(
      "ERROR: NODE_CVE_MIN is missing or invalid: " + JSON.stringify(min)
    );
    process.exit(1);
  }
  const v = process.versions.node;
  const maj = parseInt(v.split(".")[0], 10);
  const ok = maj === 24 && ge(v, min);
  if (!ok) {
    console.error(
      "ERROR: Node " + v +
      " is below CVE floor " + min + " (need Node 24.x >= " + min + ")"
    );
    process.exit(1);
  }
  console.log("Node v" + v + " meets CVE floor (>= " + min + " on 24.x)");
'

# Install NemoClaw the way NVIDIA's installer does — not `npm install -g git+...`.
# Global git installs run package prepare, which calls npm-link-or-shim while npm is
# still renaming lib/node_modules/nemoclaw → EISDIR (exit 235).
APP_VERSION="${application_version:-lkg}"
case "$APP_VERSION" in
  latest|Latest) APP_VERSION="lkg" ;;
esac

NEMOCLAW_SRC="${HOME}/.nemoclaw/source"
rm -rf "$NEMOCLAW_SRC"
mkdir -p "$(dirname "$NEMOCLAW_SRC")"
# NemoClaw onboard rejects a world-readable state dir (Unsafe portable authority).
chmod 700 "${HOME}/.nemoclaw"

git init --quiet "$NEMOCLAW_SRC"
git -C "$NEMOCLAW_SRC" remote add origin https://github.com/NVIDIA/NemoClaw.git
git -C "$NEMOCLAW_SRC" fetch --quiet --depth 1 origin "+${APP_VERSION}:refs/nemoclaw-install/target"
git -C "$NEMOCLAW_SRC" -c advice.detachedHead=false checkout --quiet --detach refs/nemoclaw-install/target
# Shallow clone only has the requested ref; fetch version tags for `git describe`.
git -C "$NEMOCLAW_SRC" fetch --depth=1 origin 'refs/tags/v*:refs/tags/v*' 2>/dev/null || true

export NEMOCLAW_INSTALLING=1
cd "$NEMOCLAW_SRC"

node scripts/lib/openshell-sdk-install.mts prepare
npm install --ignore-scripts --prefer-offline --include=optional --@nvidia:registry=https://npm.pkg.github.com
node scripts/lib/openshell-sdk-install.mts check

npm run --if-present build:cli
( cd nemoclaw && npm ci --ignore-scripts && npm run build )
npm link --ignore-scripts

# Install the system OpenShell package at NemoClaw's pinned max (onboard adopts
# /usr/bin/openshell-gateway from the package unit). Then let NemoClaw's script
# verify messaging/driver requirements.
OPENSHELL_PIN="$(sed -nE 's/^MAX_VERSION="([0-9]+\.[0-9]+\.[0-9]+)"/\1/p' \
  "${NEMOCLAW_SRC}/scripts/install-openshell.sh" | head -1)"
if [ -z "$OPENSHELL_PIN" ]; then
  echo "ERROR: could not read MAX_VERSION from NemoClaw install-openshell.sh" >&2
  exit 1
fi
export OPENSHELL_VERSION="v${OPENSHELL_PIN}"
export OPENSHELL_ACK_BREAKING_UPGRADE=1
curl -LsSf "https://raw.githubusercontent.com/NVIDIA/OpenShell/${OPENSHELL_VERSION}/install.sh" | sh
bash "${NEMOCLAW_SRC}/scripts/install-openshell.sh"

nemoclaw --version
openshell --version
/usr/bin/openshell-gateway --version || true
