#!/bin/sh

ufw limit ssh/tcp
ufw --force enable

DOCKER_AGENT_VERSION=${docker_agent_version:-$(curl -s "https://api.github.com/repos/docker/docker-agent/releases/latest" | jq -r '.tag_name')}
[ "${DOCKER_AGENT_VERSION#v}" = "$DOCKER_AGENT_VERSION" ] && DOCKER_AGENT_VERSION="v${DOCKER_AGENT_VERSION}"
DOCKER_AGENT_ARCH="amd64"
BASE_URL="https://github.com/docker/docker-agent/releases/download/${DOCKER_AGENT_VERSION}"

mkdir -p /usr/local/lib/docker-agent
curl -fL "${BASE_URL}/docker-agent-linux-${DOCKER_AGENT_ARCH}" -o /usr/local/lib/docker-agent/docker-agent || exit 1
chmod +x /usr/local/lib/docker-agent/docker-agent

if ! /usr/local/lib/docker-agent/docker-agent version >/dev/null 2>&1; then
    exit 1
fi

# CLI wrapper: upstream binary does not document DO_GRADIENT_API_KEY; append a droplet hint on help.
cat > /usr/local/bin/docker-agent << 'DOCKER_AGENT_WRAPPER_EOF'
#!/bin/sh
REAL=/usr/local/lib/docker-agent/docker-agent

do_print_gradient_hint() {
    echo ""
    echo "--- DigitalOcean 1-Click ---"
    echo "DigitalOcean Inference (Gradient): model access key at https://cloud.digitalocean.com/gen-ai"
    echo "  export DO_GRADIENT_API_KEY=your_key"
    echo "  docker-agent run /opt/docker-agent/examples/gradient_agent.yaml"
    echo "Full guide: /opt/docker-agent/README.txt"
}

if [ "$#" -eq 0 ]; then
    "$REAL" "$@"
    ec=$?
    do_print_gradient_hint
    exit "$ec"
fi

case "$1" in
-h|--help|help)
    "$REAL" "$@"
    ec=$?
    do_print_gradient_hint
    exit "$ec"
    ;;
run)
    if [ "$#" -ge 2 ] && { [ "$2" = "-h" ] || [ "$2" = "--help" ]; }; then
        "$REAL" "$@"
        ec=$?
        do_print_gradient_hint
        exit "$ec"
    fi
    ;;
esac

exec "$REAL" "$@"
DOCKER_AGENT_WRAPPER_EOF
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
printf '%s\n' '' '### DigitalOcean Inference (Gradient) (this image)' '' 'This 1-Click adds `gradient_agent.yaml`. Set `DO_GRADIENT_API_KEY` (create a key at https://cloud.digitalocean.com/gen-ai) then:' '' '```bash' 'docker-agent run /opt/docker-agent/examples/gradient_agent.yaml' '```' '' 'See `/opt/docker-agent/README.txt` for all provider keys and options.' >> README.md
cd -
# gradient_agent.yaml is provided via files/opt/docker-agent/examples/ (DigitalOcean Gradient)

chown -R root:root /opt/docker-agent
chmod -R 755 /opt/docker-agent

# MOTD (run-parts only runs executable scripts)
chmod +x /etc/update-motd.d/99-one-click

# First-login setup (runs once when root SSHs in)
chmod +x /etc/setup_docker_agent.sh
[ -f /var/lib/cloud/scripts/per-instance/001_onboot ] && chmod +x /var/lib/cloud/scripts/per-instance/001_onboot
