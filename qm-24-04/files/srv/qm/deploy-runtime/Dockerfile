# The default DEPLOY_PROVIDER=docker deploy-runtime image when
# SANDBOX_BACKEND=do-managed-agents — QM's own createDockerDeployProvider
# falls back to this automatically (src/config.ts's MANAGED_AGENTS_DEPLOY_IMAGE,
# qm-deploy-runtime:ubuntu24-node20 — see our yc-software/qm PR #2393) when
# no DEPLOY_DOCKER_IMAGE override is set. Not pulled from any registry —
# scripts/010-qm.sh builds this at Packer build time and saves it to
# /srv/qm/deploy-runtime.tar.gz; env-lib.sh's load_deploy_runtime_image()
# loads that tarball into dind's own (separate, isolated) image store once
# the stack is up, only when do-managed-agents is the droplet's actual
# chosen sandbox backend. See README.md "Docker-in-Docker for app
# publishing" for why this exists (a glibc-version mismatch between the
# Managed Agents sandbox that compiles a published app's native npm
# dependencies and the plain node:24 deploy-provider default).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Node.js 20.20.2 via NodeSource, pinned explicitly — matches the
# DigitalOcean Managed Agents sandbox's own Node ABI (NODE_MODULE_VERSION
# 115) and glibc base (Ubuntu 24.04, glibc 2.39), so a native npm addon
# compiled during an agent turn loads correctly when the published app runs
# here. gcc/g++/make/python3 come from Ubuntu 24.04's own repos (13.3.0,
# 4.3, 3.12.3 respectively, as of this writing) — node-gyp's actual build
# toolchain for packages with no prebuilt binary (e.g. better-sqlite3, whose
# npm tarball ships no prebuild at all and always falls back to a from-
# source node-gyp rebuild).
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y -qq --no-install-recommends \
    nodejs=20.20.2-1nodesource1 \
    build-essential \
    python3 \
  && rm -rf /var/lib/apt/lists/* \
  && node --version && npm --version && g++ --version | head -1 && make --version | head -1 && python3 --version
