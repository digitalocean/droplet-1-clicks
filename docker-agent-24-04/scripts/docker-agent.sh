#!/bin/sh

ufw limit ssh/tcp
ufw --force enable

DOCKER_AGENT_VERSION=${docker_agent_version:-$(curl -s "https://api.github.com/repos/docker/docker-agent/releases/latest" | jq -r '.tag_name')}
[ "${DOCKER_AGENT_VERSION#v}" = "$DOCKER_AGENT_VERSION" ] && DOCKER_AGENT_VERSION="v${DOCKER_AGENT_VERSION}"
CAGENT_ARCH="amd64"

# Docker Agent (docker-agent) releases still use the cagent binary name
DOWNLOAD_URL="https://github.com/docker/docker-agent/releases/download/${DOCKER_AGENT_VERSION}/cagent-linux-${CAGENT_ARCH}"
curl -L "$DOWNLOAD_URL" -o /usr/local/bin/cagent
chmod +x /usr/local/bin/cagent

if ! /usr/local/bin/cagent version >/dev/null 2>&1; then
    exit 1
fi

mkdir -p /opt/docker-agent/examples
cd /opt/docker-agent/examples
curl -sL https://raw.githubusercontent.com/docker/docker-agent/${DOCKER_AGENT_VERSION}/examples/basic_agent.yaml -o basic_agent.yaml
curl -sL https://raw.githubusercontent.com/docker/docker-agent/${DOCKER_AGENT_VERSION}/examples/pirate.yaml -o pirate.yaml
curl -sL https://raw.githubusercontent.com/docker/docker-agent/${DOCKER_AGENT_VERSION}/examples/dmr.yaml -o dmr.yaml
curl -sL https://raw.githubusercontent.com/docker/docker-agent/${DOCKER_AGENT_VERSION}/examples/pythonist.yaml -o pythonist.yaml
curl -sL https://raw.githubusercontent.com/docker/docker-agent/${DOCKER_AGENT_VERSION}/examples/code.yaml -o code.yaml
curl -sL https://raw.githubusercontent.com/docker/docker-agent/${DOCKER_AGENT_VERSION}/examples/todo.yaml -o todo.yaml
curl -sL https://raw.githubusercontent.com/docker/docker-agent/${DOCKER_AGENT_VERSION}/examples/README.md -o README.md
cd -

chown -R root:root /opt/docker-agent
chmod -R 755 /opt/docker-agent
