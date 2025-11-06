#!/bin/sh

ufw limit ssh/tcp
ufw --force enable

CAGENT_VERSION=${cagent_version:-$(curl -s "https://api.github.com/repos/docker/cagent/releases/latest" | jq -r '.tag_name')}
echo "DEBUG: Initial CAGENT_VERSION=$CAGENT_VERSION"
[ "${CAGENT_VERSION#v}" = "$CAGENT_VERSION" ] && CAGENT_VERSION="v${CAGENT_VERSION}"
echo "DEBUG: Final CAGENT_VERSION=$CAGENT_VERSION"
CAGENT_ARCH="amd64"


DOWNLOAD_URL="https://github.com/docker/cagent/releases/download/${CAGENT_VERSION}/cagent-linux-${CAGENT_ARCH}"
curl -L "$DOWNLOAD_URL" -o /usr/local/bin/cagent
chmod +x /usr/local/bin/cagent

if ! /usr/local/bin/cagent version >/dev/null 2>&1; then
    exit 1
fi

mkdir -p /opt/cagent/examples
cd /opt/cagent/examples
curl -sL https://raw.githubusercontent.com/docker/cagent/${CAGENT_VERSION}/examples/basic_agent.yaml -o basic_agent.yaml
curl -sL https://raw.githubusercontent.com/docker/cagent/${CAGENT_VERSION}/examples/pirate.yaml -o pirate.yaml
curl -sL https://raw.githubusercontent.com/docker/cagent/${CAGENT_VERSION}/examples/dmr.yaml -o dmr.yaml
curl -sL https://raw.githubusercontent.com/docker/cagent/${CAGENT_VERSION}/examples/pythonist.yaml -o pythonist.yaml
curl -sL https://raw.githubusercontent.com/docker/cagent/${CAGENT_VERSION}/examples/code.yaml -o code.yaml
curl -sL https://raw.githubusercontent.com/docker/cagent/${CAGENT_VERSION}/examples/todo.yaml -o todo.yaml
curl -sL https://raw.githubusercontent.com/docker/cagent/${CAGENT_VERSION}/examples/README.md -o README.md
cd -

chown -R root:root /opt/cagent
chmod -R 755 /opt/cagent
