#!/bin/sh

APP_VERSION="${application_version:-Latest}"

# Open required ports
ufw allow 80
ufw allow 443
ufw limit ssh/tcp
ufw --force enable

# Install Node.js 24 from NodeSource.
# Remediate CVE-2026-111497 (Brotli RCE): require >=24.22.1.
# VULN-5695 / VULN-5716 are internal tracker labels for that CVE.
# (Also fixed upstream in 22.23.4 and 26.12.1; OpenClaw engines are 24.x or 26.x.)
# Use a signed apt keyring instead of curling a remote setup script into bash.
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
chmod a+r /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

# Fail the Packer build if NodeSource has not yet published a patched 24.x.
# /usr/bin/openclaw uses #!/usr/bin/env node — system Node must be the CVE floor.
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
  const v = process.versions.node;
  const maj = parseInt(v.split(".")[0], 10);
  const ok = maj === 24 && ge(v, "24.22.1");
  if (!ok) {
    console.error(
      "ERROR: Node " + v +
      " is below CVE-2026-111497 minimum 24.22.1 (NodeSource node_24.x)"
    );
    process.exit(1);
  }
  console.log("Node v" + v + " meets CVE-2026-111497 floor (>=24.22.1)");
'

# Install Caddy (reverse proxy with automatic TLS)
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy

chown -R caddy:caddy /var/log/caddy
touch /var/log/caddy/access.json
chown caddy:caddy /var/log/caddy/access.json

# Create openclaw user
useradd -m -s /bin/bash openclaw || true
usermod -aG docker openclaw || true

# Install OpenClaw globally from npm
if [ "$APP_VERSION" != "Latest" ]; then
    npm install -g openclaw@${APP_VERSION}
else
    npm install -g openclaw@latest
fi

# Put the 1-Click wrapper ahead of the npm binary for interactive SSH users.
# systemd still uses /usr/bin/openclaw directly for the gateway service.
# Wrapper is shipped under files/usr/local/bin/openclaw via Packer.
chmod 0755 /usr/local/bin/openclaw

# Create openclaw home directory and config directory
mkdir -p /home/openclaw/.openclaw
mkdir -p /home/openclaw/workspace

chown -R openclaw:openclaw /home/openclaw/.openclaw
chown -R openclaw:openclaw /home/openclaw/workspace

chmod 0700 /home/openclaw/.openclaw

systemctl enable fail2ban
systemctl restart fail2ban

# Make all scripts executable
chmod +x /opt/start-openclaw.sh
chmod +x /opt/stop-openclaw.sh
chmod +x /opt/restart-openclaw.sh
chmod +x /opt/status-openclaw.sh
chmod +x /opt/update-openclaw.sh
chmod +x /opt/openclaw-cli.sh
chmod +x /opt/setup-openclaw-domain.sh
chmod +x /etc/setup_wizard.sh
chmod +x /opt/openclaw-tui.sh
chmod +x /opt/apply-inference-from-env.sh
chmod +x /var/lib/digitalocean/inference-models.sh
chmod +x /opt/sync-openclaw-gateway.sh
chmod +x /opt/openclaw-approve-ui-pairing.sh
chmod +x /opt/openclaw-control-ui-pairing.sh
chmod +x /opt/install-openclaw-pairing-hook.sh
chmod +x /opt/build-openclaw-sandbox.sh
chmod +x /opt/ensure-openclaw-ready.sh
# Required for first-boot memory headroom (Control UI / TUI on small Droplets).
if [ ! -f /opt/ensure-openclaw-swap.sh ]; then
    echo "ERROR: /opt/ensure-openclaw-swap.sh missing from image files" >&2
    exit 1
fi
chmod +x /opt/ensure-openclaw-swap.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

systemctl enable docker
systemctl start docker

chmod +x /opt/build-openclaw-sandbox.sh
/opt/build-openclaw-sandbox.sh

if [ -f /opt/openclaw.env ]; then
    sed -i "s|\${APP_VERSION}|${APP_VERSION}|g" /opt/openclaw.env
    chmod 600 /opt/openclaw.env
fi

# Enable but don't start the service yet (will start after onboot configuration)
systemctl enable openclaw

su - openclaw -c "mkdir -p /home/openclaw/.openclaw/workspace/homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /home/openclaw/.openclaw/workspace/homebrew"
# su - openclaw -c "~/homebrew/bin/brew install steipete/tap/wacli"
# su - openclaw -c "~/homebrew/bin/brew link wacli"

mkdir /home/openclaw/.openclaw/workspace/npm
chown -R openclaw /home/openclaw/.openclaw/workspace/npm
su - openclaw -c "npm config set prefix /home/openclaw/.openclaw/workspace/npm"

mkdir /home/openclaw/.openclaw/workspace/skills
chown -R openclaw /home/openclaw/.openclaw/workspace/skills
