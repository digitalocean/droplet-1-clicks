#!/bin/bash
# Update the GitHub Actions runner in place.
# Usage: /opt/update-github-runner.sh [VERSION]
#   With no args, downloads the latest release from actions/runner.
#   With VERSION (e.g. 2.336.0), installs that exact release.

set -euo pipefail

RUNNER_USER="runner"
RUNNER_DIR="/home/runner/actions-runner"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "Resolving latest actions/runner release..."
  TARGET="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')"
fi
TARGET="${TARGET#v}"

if [ -z "$TARGET" ] || [ "$TARGET" = "null" ]; then
  echo "Unable to resolve runner version." >&2
  exit 1
fi

ARCHIVE="actions-runner-linux-x64-${TARGET}.tar.gz"
URL="https://github.com/actions/runner/releases/download/v${TARGET}/${ARCHIVE}"

echo "Updating GitHub Actions Runner to v${TARGET}..."
systemctl stop actions-runner || true

cd /tmp
curl -fsSL -o "${ARCHIVE}" "${URL}"

# Preserve registration (.runner, .credentials*) and work dir; replace binaries
tmp_extract="$(mktemp -d)"
tar xzf "${ARCHIVE}" -C "${tmp_extract}"
rm -f "${ARCHIVE}"

# Copy new files over existing install without wiping config
rsync -a --exclude='.runner' --exclude='.credentials' --exclude='.credentials_rsaparams' \
  --exclude='_work' --exclude='.path' --exclude='.env' \
  "${tmp_extract}/" "${RUNNER_DIR}/"
rm -rf "${tmp_extract}"

cd "${RUNNER_DIR}"
./bin/installdependencies.sh
chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_DIR}"

if [ -f /var/lib/digitalocean/application.info ]; then
  sed -i "s/^application_version=.*/application_version=\"${TARGET}\"/" /var/lib/digitalocean/application.info
fi

if [ -f "${RUNNER_DIR}/.runner" ]; then
  systemctl start actions-runner
  echo "Updated to v${TARGET} and restarted actions-runner."
else
  echo "Updated to v${TARGET}. Runner is not registered yet; run /etc/setup-github-runner.sh"
fi
