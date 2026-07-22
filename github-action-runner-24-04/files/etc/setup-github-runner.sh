#!/bin/bash
# GitHub Actions Runner first-login setup. Registers the runner, then removes itself from root's .bashrc.

set -euo pipefail

RUNNER_DIR="/home/runner/actions-runner"
DONE_FILE="/home/runner/.runner-registered"
BASHRC="/root/.bashrc"
MARKER="# GITHUB_ACTIONS_RUNNER_FIRST_LOGIN_MARKER"

remove_first_login_hook() {
  if [ -f "$BASHRC" ]; then
    sed -i "/$MARKER/d" "$BASHRC"
    sed -i '\|/etc/setup-github-runner.sh|d' "$BASHRC"
  fi
}

# Already registered: clean hook and exit
if [ -f "$DONE_FILE" ] || [ -f "${RUNNER_DIR}/.runner" ]; then
  remove_first_login_hook
  if [ "${1:-}" != "--force" ]; then
    exit 0
  fi
fi

# Only run when we have a TTY (interactive SSH), unless --force
if [ ! -t 0 ] && [ "${1:-}" != "--force" ]; then
  exit 0
fi

cat <<'EOF'

********************************************************************************
  GitHub Actions Runner – First-login setup
********************************************************************************

This Droplet has the GitHub Actions runner pre-installed.
Register it with a repository, organization, or enterprise.

1. On GitHub: Settings → Actions → Runners → New self-hosted runner
2. Copy the repository/organization URL and the registration token
   (tokens expire after about one hour)

Docs: https://docs.github.com/en/actions/hosting-your-own-runners

EOF

read -r -p "Register this runner now? (y/n) [y]: " yn
yn=${yn:-y}
if [[ "${yn,,}" != "y" && "${yn,,}" != "yes" ]]; then
  echo ""
  echo "Skipped. Re-run anytime: /etc/setup-github-runner.sh"
  echo "Or register manually:"
  echo "  cd ${RUNNER_DIR}"
  echo "  sudo -u runner ./config.sh --url <URL> --token <TOKEN>"
  echo "  systemctl start actions-runner"
  remove_first_login_hook
  exit 0
fi

read -r -p "GitHub URL (e.g. https://github.com/ORG/REPO): " github_url
if [ -z "$github_url" ]; then
  echo "URL is required. Exiting."
  exit 1
fi

read -r -p "Registration token: " github_token
if [ -z "$github_token" ]; then
  echo "Token is required. Exiting."
  exit 1
fi

default_name="$(hostname -s)"
read -r -p "Runner name [${default_name}]: " runner_name
runner_name="${runner_name:-$default_name}"

read -r -p "Extra labels (comma-separated, optional): " runner_labels

config_args=(
  --url "$github_url"
  --token "$github_token"
  --name "$runner_name"
  --work "_work"
  --unattended
  --replace
)

if [ -n "$runner_labels" ]; then
  config_args+=(--labels "$runner_labels")
fi

echo ""
echo "Configuring runner..."
cd "$RUNNER_DIR"
sudo -u runner ./config.sh "${config_args[@]}"

touch "$DONE_FILE"
chown runner:runner "$DONE_FILE"

systemctl daemon-reload
systemctl enable actions-runner.service
systemctl restart actions-runner.service

remove_first_login_hook

cat <<EOF

********************************************************************************
  Runner registered and started.

  Status:  systemctl status actions-runner
  Logs:    journalctl -u actions-runner -f
  Stop:    systemctl stop actions-runner
  Start:   systemctl start actions-runner
  Restart: systemctl restart actions-runner

  Install path: ${RUNNER_DIR}
********************************************************************************

EOF
