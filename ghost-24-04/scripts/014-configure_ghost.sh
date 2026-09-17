################################
## PART: configure Ghost
##
## vi: syntax=sh expandtab ts=4

GHOST_VERSION="${GHOST_VERSION:-${application_version}}"

# Pull engines + packageManager from the Ghost npm package (no Node required yet).
GHOST_META=$(curl -fsSL "https://registry.npmjs.org/ghost/${GHOST_VERSION}")
NODE_RANGE=$(echo "$GHOST_META" | jq -r '.engines.node // empty')
CLI_RANGE=$(echo "$GHOST_META" | jq -r '.engines.cli // empty')
PACKAGE_MANAGER=$(echo "$GHOST_META" | jq -r '.packageManager // empty')

if [ -z "${NODE_RANGE}" ]; then
    echo "Failed to resolve engines.node for ghost@${GHOST_VERSION}" >&2
    exit 1
fi
if [ -z "${CLI_RANGE}" ]; then
    echo "Failed to resolve engines.cli for ghost@${GHOST_VERSION}" >&2
    exit 1
fi

# NodeSource stream: prefer the first ^MAJOR Ghost lists (e.g. ^22.23.1 || ^24.20.0 → 22.x).
# Optional NODE_VERSION override still wins when set (e.g. Packer -var node_version=24.x).
if [ -n "${NODE_VERSION:-}" ]; then
    VERSION="${NODE_VERSION}"
else
    NODE_MAJOR=$(echo "${NODE_RANGE}" | grep -oE '\^[0-9]+' | head -1 | tr -d '^')
    if [ -z "${NODE_MAJOR}" ]; then
        echo "Failed to parse a Node major from engines.node='${NODE_RANGE}'" >&2
        exit 1
    fi
    VERSION="${NODE_MAJOR}.x"
fi
echo "Ghost ${GHOST_VERSION} requires Node ${NODE_RANGE}; installing NodeSource ${VERSION}"

curl -fsSL "https://deb.nodesource.com/setup_${VERSION}" -o nodesource_setup.sh
sudo -E bash nodesource_setup.sh

# Run update and install
sudo apt-get update
sudo apt-get install nodejs -y

# pnpm: use Ghost's packageManager pin when present (e.g. pnpm@12.4.0+sha512...), else latest.
if echo "${PACKAGE_MANAGER}" | grep -q '^pnpm@'; then
    PNPM_VERSION=$(echo "${PACKAGE_MANAGER}" | sed -n 's/^pnpm@\([^+[:space:]]*\).*/\1/p')
else
    PNPM_VERSION="latest"
fi
echo "Ghost ${GHOST_VERSION} packageManager='${PACKAGE_MANAGER:-unset}'; preparing pnpm@${PNPM_VERSION}"
corepack enable
corepack prepare "pnpm@${PNPM_VERSION}" --activate

useradd --home-dir /home/ghost-mgr \
        --shell /bin/bash \
        --create-home \
        --comment 'Ghost Management User' \
        --groups sudo \
        ghost-mgr

cat > /etc/sudoers.d/99-do-ghost <<EOM
# Created by DigitalOcean 1-Click for Ghost CLI management.
ghost-mgr ALL=(ALL) NOPASSWD:ALL
EOM

chmod 755 /var/www
mkdir -p /var/www/ghost
chown -R ghost-mgr: /var/www/ghost
chmod 775 /var/www/ghost

# Resolve Ghost-CLI from Ghost's published engines.cli (latest release that satisfies it).
CLI_RESOLVED=$(npm view "ghost-cli@${CLI_RANGE}" version --json --silent | jq -r 'if type == "array" then .[-1] else . end')
if [ -z "${CLI_RESOLVED}" ] || [ "${CLI_RESOLVED}" = "null" ]; then
    echo "Failed to resolve a Ghost-CLI version for range ${CLI_RANGE}" >&2
    exit 1
fi
echo "Ghost ${GHOST_VERSION} requires Ghost-CLI ${CLI_RANGE}; installing ${CLI_RESOLVED}"

su ghost-mgr -c "bash -x <<EOM
sudo npm i -g ghost-cli@${CLI_RESOLVED} > /tmp/npm.log || { tail -n 100 /tmp/npm.log; exit 1; }
EOM
"
