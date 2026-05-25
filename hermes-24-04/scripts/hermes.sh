#!/bin/sh
set -e

APP_VERSION="${application_version:-main}"
INSTALLER=/tmp/hermes-install.sh
HERMES_USER=hermes
HERMES_HOME=/home/hermes/.hermes
HERMES_BIN=/home/hermes/.local/bin/hermes

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

case "$APP_VERSION" in
    *[!A-Za-z0-9._-]*)
        echo "ERROR: unsupported Hermes version/branch: $APP_VERSION" >&2
        exit 1
        ;;
esac

curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/${APP_VERSION}/scripts/install.sh" -o "$INSTALLER"
chmod 0755 "$INSTALLER"

su - "$HERMES_USER" -c "HERMES_HOME=$HERMES_HOME bash $INSTALLER --skip-setup --skip-browser --branch $APP_VERSION"
rm -f "$INSTALLER"

if [ ! -x "$HERMES_BIN" ]; then
    echo "ERROR: Hermes CLI not found after install (expected $HERMES_BIN)." >&2
    exit 1
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
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

su - "$HERMES_USER" -c "$HERMES_BIN --version" || true
