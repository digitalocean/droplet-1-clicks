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

# Build `core` from v-aisac/qm's own "droplet-pin-no-csp" branch — not
# itself an upstream PR, just this droplet's own integration branch
# cherry-picking two independent, still-unmerged upstream PRs this droplet
# needs, deliberately WITHOUT a third (#2388) this particular droplet
# doesn't need:
#
#   - yc-software/qm PR #2393 (fix/deploy-image-managed-agents):
#     `createDockerDeployProvider`'s deploy-runtime image automatically
#     becomes qm-deploy-runtime:ubuntu24-node20 (built below, see README.md
#     "Docker-in-Docker for app publishing") instead of its own node:24
#     default, specifically when SANDBOX_BACKEND=do-managed-agents — a
#     published app's native npm dependencies are compiled in that sandbox
#     (Ubuntu 24.04, glibc 2.39), and node:24 (Debian bookworm, glibc 2.36)
#     is one glibc minor version short of what some of them need.
#   - yc-software/qm PR #2399 (fix/docker-deploy-data-dir):
#     `createDockerDeployProvider` now sets DATA_DIR=/data, backed by a
#     named Docker volume per deployment, and reports it via
#     profile.dataDir — every other deploy provider (aws/e2b/porter/fly)
#     already did this; without it, a published app's own state (e.g. a
#     SQLite DB) lived only in that container's writable layer and was
#     silently lost on every redeploy.
#
# Deliberately EXCLUDES yc-software/qm PR #2388 (fix/deployment-app-sandbox-
# cookies, `APP_SANDBOX_CSP` gains allow-same-origin): that fix is a real
# security tradeoff needed only when a droplet has no DEPLOY_APPS_DOMAIN
# configured and so serves every published app through the path-based,
# same-origin `/d/<id>/` proxy — see README.md "Docker-in-Docker for app
# publishing" for the full bug and why it's not a clean upstream fix. A
# droplet with a real apps domain configured (this one) serves every app
# from its own genuinely separate subdomain instead, with no sandbox CSP
# applied at all, so it was never affected by that bug and doesn't need
# the fix — including it here would be weakening isolation for no reason.
#
# Each of #2393/#2399 is independent and reviewable on its own upstream;
# this branch exists only so this droplet can build with both until each
# is merged or resolved — switch back to tracking yc-software/qm main
# directly once they land, or re-cut this branch otherwise.
QM_REPO="https://github.com/v-aisac/qm.git"
QM_SHA="4b37691d854690524b1c0d91667dec3ff1111189"
QM_CORE_TAG="qm-core:4b37691d"

echo "Building core (${QM_CORE_TAG}) from ${QM_REPO} @ ${QM_SHA}..."
BUILD_DIR="$(mktemp -d)"
git -C "$BUILD_DIR" init -q
git -C "$BUILD_DIR" remote add origin "$QM_REPO"
git -C "$BUILD_DIR" fetch -q --depth 1 origin "$QM_SHA"
git -C "$BUILD_DIR" checkout -q FETCH_HEAD

# Confirmed with an actual `docker build --no-cache` at this pin (not just
# reading the Dockerfile): no npm-audit-gate patch needed — deploy/core/
# Dockerfile doesn't run one at all at this commit. Earlier fork-era pins
# needed a sed-patch here to strip a `npm audit --audit-level=moderate`
# gate; that patch is in this file's git history if a future pin bump ever
# reintroduces one.
docker build \
  -f "$BUILD_DIR/deploy/core/Dockerfile" \
  -t "$QM_CORE_TAG" \
  --build-arg "GIT_SHA=${QM_SHA}" \
  "$BUILD_DIR"
rm -rf "$BUILD_DIR"

# Build the deploy-runtime image PR #2393 above makes core fall back to for
# SANDBOX_BACKEND=do-managed-agents (Ubuntu 24.04 + Node 20.20.2 + build-
# essential + python3 — exactly matching the Managed Agents sandbox's own
# environment component-for-component, confirmed live: a real native addon
# with no prebuilt binary at all, better-sqlite3, compiles via node-gyp and
# loads correctly here). Not pulled from any registry, and dind (the actual
# Docker daemon DEPLOY_PROVIDER=docker drives — see README.md) has its own
# image cache entirely separate from this host's, so it can't just be built
# here and left — saved to a tarball instead; env-lib.sh's
# load_deploy_runtime_image() loads it into dind once the real stack is up
# at boot, only when do-managed-agents ends up being this droplet's actual
# chosen sandbox backend (see 001_onboot/setup_wizard.sh).
echo "Building deploy-runtime image (qm-deploy-runtime:ubuntu24-node20)..."
docker build -t qm-deploy-runtime:ubuntu24-node20 /srv/qm/deploy-runtime
docker save qm-deploy-runtime:ubuntu24-node20 | gzip > /srv/qm/deploy-runtime.tar.gz
docker rmi qm-deploy-runtime:ubuntu24-node20 >/dev/null

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
