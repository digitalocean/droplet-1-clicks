#!/bin/sh

ufw limit ssh/tcp
ufw --force enable

DOCKER_AGENT_VERSION=${docker_agent_version:-$(curl -s "https://api.github.com/repos/docker/docker-agent/releases/latest" | jq -r '.tag_name')}
[ "${DOCKER_AGENT_VERSION#v}" = "$DOCKER_AGENT_VERSION" ] && DOCKER_AGENT_VERSION="v${DOCKER_AGENT_VERSION}"
DOCKER_AGENT_ARCH="amd64"
BASE_URL="https://github.com/docker/docker-agent/releases/download/${DOCKER_AGENT_VERSION}"

curl -fL "${BASE_URL}/docker-agent-linux-${DOCKER_AGENT_ARCH}" -o /usr/local/bin/docker-agent || exit 1
chmod +x /usr/local/bin/docker-agent

if ! /usr/local/bin/docker-agent version >/dev/null 2>&1; then
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
# gradient_agent.yaml is provided via files/opt/docker-agent/examples/ (DigitalOcean Gradient)

chown -R root:root /opt/docker-agent
chmod -R 755 /opt/docker-agent

# MOTD (run-parts only runs executable scripts)
chmod +x /etc/update-motd.d/99-one-click

# First-login setup (runs once when root SSHs in)
chmod +x /etc/setup_docker_agent.sh
[ -f /var/lib/cloud/scripts/per-instance/001_onboot ] && chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
