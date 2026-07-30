#!/bin/bash
set -euo pipefail

# RUNNER_VERSION is set from application_version in template.json
RUNNER_USER="runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_DIR="${RUNNER_HOME}/actions-runner"
RUNNER_ARCHIVE="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}"

echo "Installing GitHub Actions Runner v${RUNNER_VERSION}..."

# Dedicated non-root user for the runner
if ! id -u "${RUNNER_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${RUNNER_USER}"
fi

# Allow Docker-based workflow jobs (local docker.sock only)
if getent group docker >/dev/null 2>&1; then
  usermod -aG docker "${RUNNER_USER}"
fi

mkdir -p "${RUNNER_DIR}"
cd /tmp
curl -fsSL -o "${RUNNER_ARCHIVE}" "${RUNNER_URL}"
tar xzf "${RUNNER_ARCHIVE}" -C "${RUNNER_DIR}"
rm -f "${RUNNER_ARCHIVE}"

# Install runner OS dependencies (libicu, etc.)
cd "${RUNNER_DIR}"
./bin/installdependencies.sh

chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}"

# Make shipped scripts executable
chmod +x /etc/update-motd.d/99-one-click
chmod +x /etc/setup-github-runner.sh
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
chmod +x /opt/start-github-runner.sh
chmod +x /opt/stop-github-runner.sh
chmod +x /opt/restart-github-runner.sh
chmod +x /opt/status-github-runner.sh
chmod +x /opt/update-github-runner.sh

# First-login wizard hook from shipped snippet (removed after registration)
if ! grep -q 'setup-github-runner.sh' /root/.bashrc 2>/dev/null; then
  printf '\n' >> /root/.bashrc
  cat /etc/github-runner-bashrc.snippet >> /root/.bashrc
fi

# SSH-only UFW. Keep Docker forward policy so container networking works;
# do not open Docker API ports 2375/2376.
ufw --force reset
sed -e 's|DEFAULT_FORWARD_POLICY=.*|DEFAULT_FORWARD_POLICY="ACCEPT"|g' \
    -i /etc/default/ufw
ufw default deny incoming
ufw default allow outgoing
ufw limit ssh
ufw --force enable

# Enable the unit (starts only after registration creates .runner)
systemctl daemon-reload
systemctl enable actions-runner.service

echo "GitHub Actions Runner v${RUNNER_VERSION} installed to ${RUNNER_DIR}"
echo "Register on first boot/login via /etc/setup-github-runner.sh"
