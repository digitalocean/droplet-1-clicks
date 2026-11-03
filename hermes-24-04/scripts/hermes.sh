#!/bin/sh
set -e

APP_VERSION="${application_version:-latest}"
INSTALLER=/tmp/hermes-install.sh
HERMES_USER=hermes
HERMES_HOME=/home/hermes/.hermes
HERMES_BIN=/home/hermes/.local/bin/hermes
LATEST_RELEASE_URL=https://github.com/NousResearch/hermes-agent/releases/latest

# Terminal-first image: keep only SSH exposed by default.
ufw limit ssh/tcp
ufw --force enable

useradd -m -s /bin/bash "$HERMES_USER" || true
mkdir -p "$HERMES_HOME" /home/hermes/workspace
chown -R hermes:hermes "$HERMES_HOME" /home/hermes/workspace
chmod 0700 "$HERMES_HOME"

systemctl enable fail2ban
systemctl restart fail2ban

rm -f "$INSTALLER"

if [ "$APP_VERSION" = "latest" ]; then
    APP_VERSION="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$LATEST_RELEASE_URL" | sed 's#.*/##')"

    if [ -z "$APP_VERSION" ] || [ "$APP_VERSION" = "latest" ]; then
        echo "ERROR: unable to resolve the latest Hermes release tag." >&2
        exit 1
    fi
fi

case "$APP_VERSION" in
    *[!A-Za-z0-9._-]*)
        echo "ERROR: unsupported Hermes version reference: $APP_VERSION" >&2
        exit 1
        ;;
esac

curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/${APP_VERSION}/scripts/install.sh" -o "$INSTALLER"
chmod 0755 "$INSTALLER"

# Release tags are refs/tags/*, not branches. --branch v0.22.6 makes the
# installer fetch refs/heads/v0.22.6 and fail. --commit pins that tag.
# Do not pass --channel main: that saves the main update channel, and a
# later `hermes update` follows main's tip instead of this release.
# The upstream installer otherwise rejects a tag cut from a release branch
# because it is not an ancestor of main. If a future installer drops that
# check, leave it unchanged and continue.
HERMES_COMMIT="$(git ls-remote https://github.com/NousResearch/hermes-agent.git "refs/tags/${APP_VERSION}^{}" | awk 'NR==1 { print $1 }')"
if [ -z "$HERMES_COMMIT" ]; then
    HERMES_COMMIT="$(git ls-remote https://github.com/NousResearch/hermes-agent.git "refs/tags/${APP_VERSION}" | awk 'NR==1 { print $1 }')"
fi
if [ -z "$HERMES_COMMIT" ]; then
    echo "ERROR: ${APP_VERSION} is not a Hermes release tag." >&2
    exit 1
fi

awk -v tag="$APP_VERSION" '
    function emit_fetch(dir,    indent) {
        indent = (dir == "$staged/tree") ? "            " : "        "
        print indent "git -C \"" dir "\" cat-file -e \"${INSTALL_COMMIT}^{commit}\" 2>/dev/null \\"
        print indent "    || git -C \"" dir "\" fetch --no-tags origin \"+refs/tags/" tag ":refs/tags/" tag "\" \\"
        if (dir == "$staged/tree") {
            print indent "    || { rm -rf \"$staged\"; fail \"could not fetch release tag\" commit_not_on_branch; }"
        } else {
            print indent "    || fail \"could not fetch release tag\" commit_not_on_branch"
        }
    }
    {
        if (have) {
            if (prev ~ /git -C "\$staged\/tree" merge-base --is-ancestor "\$INSTALL_COMMIT"/ && /not on branch \$BRANCH/) {
                emit_fetch("$staged/tree")
                have = 0
                next
            }
            if (prev ~ /git -C "\$INSTALL_DIR" merge-base --is-ancestor "\$INSTALL_COMMIT"/ && /not on branch \$BRANCH/) {
                emit_fetch("$INSTALL_DIR")
                have = 0
                next
            }
            print prev
        }
        prev = $0
        have = 1
    }
    END { if (have) print prev }
' "$INSTALLER" >"${INSTALLER}.patched"
mv "${INSTALLER}.patched" "$INSTALLER"
chmod 0755 "$INSTALLER"
su - "$HERMES_USER" -c "HERMES_HOME=$HERMES_HOME bash $INSTALLER --skip-setup --skip-browser --commit $HERMES_COMMIT"
rm -f "$INSTALLER"

if [ ! -x "$HERMES_BIN" ]; then
    echo "ERROR: Hermes CLI not found after install (expected $HERMES_BIN)." >&2
    exit 1
fi

# Tag-only shallow clones leave detached HEAD without origin/main, which breaks
# `hermes update`. Expand remotes and fetch main/tags so helpers can upgrade.
HERMES_AGENT_DIR="$HERMES_HOME/hermes-agent"
if [ -d "$HERMES_AGENT_DIR/.git" ]; then
    su - "$HERMES_USER" -c "
        set -e
        cd $HERMES_AGENT_DIR
        git remote set-branches origin '*' >/dev/null 2>&1 || true
        git fetch --unshallow origin >/dev/null 2>&1 || true
        git fetch origin main >/dev/null 2>&1 || true
        git fetch --tags origin >/dev/null 2>&1 || true
    " || true
fi

# Put a root-friendly wrapper on PATH while keeping the real user install intact.
cat > /usr/local/bin/hermes <<'EOF'
#!/bin/sh
exec /opt/hermes/hermes-cli.sh "$@"
EOF
chmod 0755 /usr/local/bin/hermes

chmod +x /opt/hermes/hermes-cli.sh
chmod +x /opt/hermes/status-hermes.sh
chmod +x /opt/hermes/update-hermes.sh
chmod +x /opt/hermes/doctor-hermes.sh
chmod +x /opt/hermes/remediate-npm.sh
chmod +x /opt/hermes/apply-inference-from-env.sh
chmod +x /var/lib/digitalocean/inference-models.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Record the image pin for /opt/hermes/update-hermes.sh.
if grep -q '^HERMES_VERSION=' /opt/hermes/hermes.env 2>/dev/null; then
    sed -i "s|^HERMES_VERSION=.*|HERMES_VERSION=${APP_VERSION}|" /opt/hermes/hermes.env
else
    printf '\nHERMES_VERSION=%s\n' "$APP_VERSION" >> /opt/hermes/hermes.env
fi

# Clear npm advisories that hermes doctor flags on web / ui-tui workspaces.
/opt/hermes/remediate-npm.sh || true

su - "$HERMES_USER" -c "$HERMES_BIN --version" || true
