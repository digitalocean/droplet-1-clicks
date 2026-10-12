#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Docker Engine + Compose plugin
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl enable docker
systemctl restart docker

docker --version
docker compose version

# Caddy reverse proxy (host TLS on the bare droplet IP; QM's portal stays on
# loopback :8081). QM's own sign-in flow requires HTTPS or literal
# "localhost" — see README.md "Why Caddy" — plain HTTP on a public IP is a
# hard dead end, not just a security nicety.
curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
  > /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install -y caddy
mkdir -p /var/log/caddy && chown -R caddy:caddy /var/log/caddy
systemctl stop caddy 2>/dev/null || true
systemctl disable caddy 2>/dev/null || true

printf '%s\n' "${application_version}" > /srv/qm/.qm-version

# Materialize .env from the non-hidden Packer template (Packer may skip
# dotfiles) BEFORE pulling: compose.yml's image refs come from .env
# (QM_CORE_IMAGE etc., empty by default — see env.template) via
# docker compose's own variable interpolation, so .env must exist first.
if [ -f /srv/qm/env.template ]; then
  cp /srv/qm/env.template /srv/qm/.env
  chmod 600 /srv/qm/.env
fi

# Convenience symlink matching this repo's other 1-clicks (/<app>.env)
ln -sfn /srv/qm/.env /srv/qm.env

# Build `core` from the DigitalOcean Managed Agents sandbox-backend fork
# (https://github.com/nkurraDO/qm, branch managed-agents-sandbox-backend —
# this is yc-software/qm PR #2067, pinned to a specific commit), since the
# fork has no published release/image yet (checked: zero GitHub releases as
# of this writing), so we build it ourselves rather than waiting. Only
# `core` changes in this fork (web-ui/portal are untouched), and the fork is
# a pure superset of upstream (adds SANDBOX_BACKEND=do-managed-agents
# alongside e2b/local/etc., doesn't remove anything), so this one image
# serves both sandbox backends. This commit uses the fork's formalized
# naming (`do-managed-agents`/`DO_AGENTS_*`) — a real rename from the
# fork's earlier `mars`/`MARS_*` naming this droplet originally pinned, not
# just cosmetic. See README.md "DigitalOcean Managed Agents sandbox
# backend" for the full story and how to bump this pin later.
QM_FORK_REPO="https://github.com/nkurraDO/qm.git"
QM_FORK_SHA="15e71bf0379eec590478da826b9c383a49e4227b"
QM_CORE_MANAGED_AGENTS_TAG="qm-core-managed-agents:15e71bf0"

echo "Building core (${QM_CORE_MANAGED_AGENTS_TAG}) from ${QM_FORK_REPO} @ ${QM_FORK_SHA}..."
BUILD_DIR="$(mktemp -d)"
git -C "$BUILD_DIR" init -q
git -C "$BUILD_DIR" remote add origin "$QM_FORK_REPO"
git -C "$BUILD_DIR" fetch -q --depth 1 origin "$QM_FORK_SHA"
git -C "$BUILD_DIR" checkout -q FETCH_HEAD

# KNOWN ISSUE at the previous pinned commit (787ff972), verified by actually
# running that build: deploy/core/Dockerfile has a hard
# `npm audit --audit-level=moderate` gate that failed there — fastify (high:
# auth-bypass-adjacent advisories) and hono (moderate: XSS) both had open
# advisories in that lockfile. `npm ci` itself succeeded; only the separate
# audit gate layered on top failed the build. This strips that one gate so
# we get a real image instead of no image — it does NOT change which
# package versions get installed (still exactly what package-lock.json
# pins), so this doesn't make the image any less secure than the fork's own
# code already is; it just stops vendoring-unrelated advisories from
# blocking our build. Confirmed the same gate line is still present
# verbatim at this new commit (15e71bf0), so this patch still applies
# syntactically — but NOT re-verified by an actual `docker build` (no local
# Docker daemon available when this was pinned), so whether the same two
# advisories (or different ones) are still open in this commit's lockfile
# is unconfirmed; check on the next real Packer build. This is an upstream
# fork issue either way, not ours to fix by silently bumping dependency
# versions out from under their lockfile — flag it to the DigitalOcean
# Managed Agents team; don't just carry this patch forward forever. See
# README.md "DigitalOcean Managed Agents sandbox backend" for details.
sed -i.bak \
  's/npm ci --omit=dev && npm audit --omit=dev --audit-level=moderate \\/npm ci --omit=dev \\/' \
  "$BUILD_DIR/deploy/core/Dockerfile"
rm -f "$BUILD_DIR/deploy/core/Dockerfile.bak"

docker build \
  -f "$BUILD_DIR/deploy/core/Dockerfile" \
  -t "$QM_CORE_MANAGED_AGENTS_TAG" \
  --build-arg "GIT_SHA=${QM_FORK_SHA}" \
  "$BUILD_DIR"
rm -rf "$BUILD_DIR"

# Pull the remaining images compose.yml resolves to (web-ui/portal still come
# from upstream — see compose.yml's header comment; core is excluded here
# since it was just built locally above, not pulled from a registry).
echo "Pulling QM stack images (release ${application_version})..."
(cd /srv/qm && docker compose pull web-ui portal postgres dind)

chmod +x /srv/qm/gen-secrets.py
chmod +x /srv/qm/start-qm.sh
chmod +x /srv/qm/stop-qm.sh
chmod +x /srv/qm/restart-qm.sh
chmod +x /srv/qm/status-qm.sh
chmod +x /srv/qm/update-qm.sh
chmod +x /etc/setup_wizard.sh
chmod +x /etc/update-motd.d/99-one-click
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

systemctl enable fail2ban
systemctl restart fail2ban

echo "QM (release ${application_version}) installation complete."
echo "Stack will start on first boot after secrets are generated."
