# A custom DigitalOcean Managed Agents sandbox template ("Bring Your Own
# Template" — see
# https://docs.digitalocean.com/products/managed-agents/agent-harness-runtime/how-to/use-custom-template/),
# pinning the sandbox's environment to the exact same dependency versions as
# this droplet's deploy-runtime image (files/srv/qm/deploy-runtime/Dockerfile)
# instead of relying on DigitalOcean's own implicit default sandbox — the
# opposite direction from that image: there, we made the *deploy* side match
# the sandbox's environment; here, we pin the *sandbox* side explicitly so it
# can never silently drift away from the deploy side again. Base image/
# component versions below were established empirically earlier in this
# project (confirmed live against the real default Managed Agents sandbox,
# and against what a real native npm dependency with no prebuilt binary —
# better-sqlite3 — actually needs to compile and load): Ubuntu 24.04
# (glibc 2.39), Node.js 20.20.2 (NODE_MODULE_VERSION 115), npm 10.8.2,
# gcc/g++ 13.3.0, make 4.3, python3 3.12.3.
#
# Platform constraints this Dockerfile follows (from the doc above — "Image
# Requirements" section):
#   - linux/amd64, glibc-based (Ubuntu here) — Alpine/musl isn't supported
#     by default. Minimum glibc for this install's base-template ("sandbox",
#     matching QM's own deploy/do-managed-agents/register-template.sh
#     precedent rather than one of the DO-native adapter bases like
#     codex-base/claude-code-base/hermes-base/opencode-base/langgraph-base
#     — QM brings its own agent harness, it doesn't use any of those) is
#     2.17+; Ubuntu 24.04's 2.39 clears that easily.
#   - The image's own USER instruction is ignored (the agent always runs as
#     UID 10001), so none is set here.
#   - The platform already supplies the agent runtime itself, bash, git, gh,
#     and a CA certificate bundle — only install what's genuinely extra.
#   - ENTRYPOINT must be a long-running command (the container is PID 1 and
#     must stay up for the whole session) — sleep infinity, matching QM's
#     own reference Dockerfile at deploy/do-managed-agents/Dockerfile.
#   - HOME=/workspace/home, also matching that same reference Dockerfile —
#     /workspace itself is platform-owned/mounted at runtime, not something
#     this image's build ever writes into, so pointing HOME there is safe
#     (the doc's "don't bake files under /workspace" warning is about COPYing
#     build-time content into that path, not about an env var naming it).
#
# To build, push, and register this as a template, see QM's own
# deploy/do-managed-agents/register-template.sh for the exact doctl
# commands (docker build --platform linux/amd64, push to a DO Container
# Registry, then `doctl harness-runtime template create --base-template
# sandbox --source-oci-ref <image>`) — not duplicated here since that
# script already does exactly this, generically, against whichever
# Dockerfile directory it's pointed at.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Same general-purpose tool set QM's own reference sandbox Dockerfile
# installs (deploy/do-managed-agents/Dockerfile), translated to Ubuntu's apt
# packages (identical names to Debian's for all of these) — plus Node.js
# 20.20.2 (NodeSource, pinned — matching files/srv/qm/deploy-runtime/Dockerfile
# exactly) and build-essential, since agent turns running in this sandbox
# are what actually compile a published app's native npm dependencies (e.g.
# better-sqlite3, which ships no prebuilt binary at all and always falls
# back to a from-source node-gyp rebuild) — QM's own reference image never
# needed this because it only ever ran Node's own bundled toolchain, not a
# pinned Node version matched against a separate deploy-runtime image.
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    ca-certificates curl gnupg \
    git wget jq tar xz-utils unzip zip ripgrep \
    openssh-client less procps \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y -qq --no-install-recommends \
    nodejs=20.20.2-1nodesource1 \
    build-essential \
    python3 python3-pip python3-venv \
  && rm -rf /var/lib/apt/lists/* \
  && node --version && npm --version && g++ --version | head -1 && make --version | head -1 && python3 --version

ENV HOME=/workspace/home
ENTRYPOINT ["sleep", "infinity"]
CMD []
