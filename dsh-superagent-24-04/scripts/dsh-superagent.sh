#!/bin/bash
# Build-time install of DSH Superagent (runs as root on the build Droplet).
#
# Installs the GitHub CLI, creates the dedicated `superagent` user, clones the
# upstream repository at a pinned commit, installs and builds it, and creates
# the `superagent` DeepSeek Harness profile. Secrets are never written here:
# the DeepSeek key and the agent's GitHub login are entered at first login.
set -euo pipefail

: "${application_version:?}"
: "${dsh_superagent_commit:?}"
: "${dsh_version:?}"
: "${pnpm_version:?}"
: "${gh_version:?}"
: "${gh_sha256:?}"

APP_USER=superagent
APP_HOME=/home/superagent
APP_DIR=$APP_HOME/dsh-superagent
REPO_URL=https://github.com/deepseek-ai/dsh-superagent-prototype.git
OPT_DIR=/opt/dsh-superagent

# Run a command as the application user with a clean, explicit environment.
as_app() {
    runuser -u "$APP_USER" -- env -i \
        HOME="$APP_HOME" USER="$APP_USER" LOGNAME="$APP_USER" \
        PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 "$@"
}

echo "== GitHub CLI ${gh_version} (pinned, checksum verified)"
tmp=$(mktemp -d)
gh_archive="gh_${gh_version}_linux_amd64.tar.gz"
curl -fsSL -o "$tmp/$gh_archive" \
    "https://github.com/cli/cli/releases/download/v${gh_version}/${gh_archive}"
echo "${gh_sha256}  $tmp/$gh_archive" | sha256sum -c -
tar -xzf "$tmp/$gh_archive" -C "$tmp" "gh_${gh_version}_linux_amd64/bin/gh"
install -m 0755 "$tmp/gh_${gh_version}_linux_amd64/bin/gh" /usr/local/bin/gh
rm -rf "$tmp"
gh --version | head -n 1

echo "== application user"
id -u "$APP_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$APP_USER"

echo "== pnpm ${pnpm_version} and dsh ${dsh_version}"
npm install --global "pnpm@${pnpm_version}" "@deepseek-ai/dsh@${dsh_version}"
dsh --version

echo "== upstream checkout at ${dsh_superagent_commit}"
rm -rf "$APP_DIR"
git clone --quiet "$REPO_URL" "$APP_DIR"
git -C "$APP_DIR" -c advice.detachedHead=false checkout --quiet "$dsh_superagent_commit"
test "$(git -C "$APP_DIR" rev-parse HEAD)" = "$dsh_superagent_commit"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo "== dependencies and build"
as_app bash -c "cd '$APP_DIR' && pnpm install --frozen-lockfile && pnpm build"

echo "== DeepSeek Harness profile 'superagent'"
as_app bash -c "cd '$APP_HOME' && dsh superagent --from-default-profile web --dump-config > /dev/null"
as_app bash -c "cd '$APP_HOME' && dsh plugin --profile superagent add 'link:$APP_DIR'"

echo "== OpenAI-compatible gateway for DigitalOcean Inference"
# pnpm 11 refuses to finish while these dependency scripts are neither approved
# nor declined. Approve them before the install so the plugin add can exit 0.
profile_workspace="$APP_HOME/.dsh/profiles/superagent/pnpm-workspace.yaml"
if ! grep -q '^allowBuilds:' "$profile_workspace"; then
    cat >> "$profile_workspace" <<'EOF'

allowBuilds:
  "@google/genai": true
  protobufjs: true
EOF
    chown "$APP_USER:$APP_USER" "$profile_workspace"
fi
if ! as_app bash -c "cd '$APP_HOME' && dsh plugin --profile superagent add '@deepseek-ai/dsh-llm-pi-ai@${dsh_version}'"; then
    as_app bash -c "cd '$APP_HOME/.dsh/profiles/superagent' && pnpm approve-builds --all && pnpm install"
fi
grep -q '"@deepseek-ai/dsh-llm-pi-ai"' "$APP_HOME/.dsh/profiles/superagent/package.json"

echo "== machine configuration"
install -d -o "$APP_USER" -g "$APP_USER" -m 0750 "$APP_HOME/.dsh/state/superagent"
install -o "$APP_USER" -g "$APP_USER" -m 0644 \
    "$OPT_DIR/profile.cordis.patch.yml" \
    "$APP_HOME/.dsh/profiles/superagent/cordis.patch.yml"
install -d -o "$APP_USER" -g "$APP_USER" -m 0755 "$APP_HOME/src"
# Create each level with the application user as owner, so the agent's gh
# configuration directory under ~/.config can be written later.
install -d -o "$APP_USER" -g "$APP_USER" -m 0755 "$APP_HOME/.config"
install -d -o "$APP_USER" -g "$APP_USER" -m 0700 "$APP_HOME/.config/dsh-superagent"

echo "== permissions"
chmod 0755 "$OPT_DIR"/*.sh "$OPT_DIR/gh-agent"
chmod 0755 /etc/setup_wizard.sh
chmod 0644 /etc/profile.d/dsh-superagent-setup.sh
chmod 0755 /etc/update-motd.d/99-one-click
chmod 0755 /var/lib/cloud/scripts/per-instance/001_onboot
chmod 0644 /etc/systemd/system/dsh-superagent.service \
    /etc/systemd/system/dsh-superagent-check.service \
    /etc/systemd/system/dsh-superagent-check.timer \
    /etc/systemd/system/dsh-superagent-apply-inference.service
chmod 0644 "$OPT_DIR/dsh-superagent-inference.env"
systemctl daemon-reload

echo "== firewall: SSH only; the panel stays on 127.0.0.1 and is reached through an SSH tunnel"
ufw limit ssh/tcp
ufw --force enable
systemctl enable fail2ban
systemctl restart fail2ban

echo "== smoke check"
as_app bash -c "dsh --version && test -f '$APP_HOME/.dsh/profiles/superagent/cordis.patch.yml'"
test -x "$OPT_DIR/superagent-ctl.sh"
echo "DSH Superagent ${application_version} (commit ${dsh_superagent_commit}) installed."
