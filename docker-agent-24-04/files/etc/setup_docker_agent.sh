#!/bin/bash
# Docker Agent first-login setup. Runs once, then removes itself from root's .bashrc.

DONE_FILE="/opt/docker-agent/.first-login-done"
BASHRC="/root/.bashrc"
MARKER="# DOCKER_AGENT_FIRST_LOGIN_MARKER"

# Strip surrounding single/double quotes from key (e.g. "api-key" -> api-key)
strip_quotes() { echo "$1" | sed -e "s/^[\"']//" -e "s/[\"']$//"; }

# Already ran once: remove this script from .bashrc and exit
if [ -f "$DONE_FILE" ]; then
    sed -i "/$MARKER/d" "$BASHRC"
    sed -i '\|/etc/setup_docker_agent.sh|d' "$BASHRC"
    exit 0
fi

# Only run when we have a TTY (interactive SSH)
if [ ! -t 0 ]; then
    exit 0
fi

SET_OPENAI=""
SET_ANTHROPIC=""
SET_GRADIENT=""

echo ""
echo "********************************************************************************"
echo "  Docker Agent – First-login setup"
echo "********************************************************************************"
echo ""
echo "You can set an API key now so 'docker-agent run ...' works without exporting each time."
echo "Leave blank to skip and set later."
echo ""

read -p "Set OPENAI_API_KEY now? (y/n) [n]: " yn
yn=${yn:-n}
if [[ "${yn,,}" == "y" || "${yn,,}" == "yes" ]]; then
    read -p "Enter your OPENAI_API_KEY: " key
    key=$(strip_quotes "$key")
    if [ -n "$key" ]; then
        if grep -q 'OPENAI_API_KEY' "$BASHRC" 2>/dev/null; then
            sed -i "s|^export OPENAI_API_KEY=.*|export OPENAI_API_KEY='$key'|" "$BASHRC"
        else
            echo "export OPENAI_API_KEY='$key'" >> "$BASHRC"
        fi
        echo "OPENAI_API_KEY added to /root/.bashrc (loaded on next login)."
        SET_OPENAI=1
    fi
fi

read -p "Set ANTHROPIC_API_KEY now? (y/n) [n]: " yn
yn=${yn:-n}
if [[ "${yn,,}" == "y" || "${yn,,}" == "yes" ]]; then
    read -p "Enter your ANTHROPIC_API_KEY: " key
    key=$(strip_quotes "$key")
    if [ -n "$key" ]; then
        if grep -q 'ANTHROPIC_API_KEY' "$BASHRC" 2>/dev/null; then
            sed -i "s|^export ANTHROPIC_API_KEY=.*|export ANTHROPIC_API_KEY='$key'|" "$BASHRC"
        else
            echo "export ANTHROPIC_API_KEY='$key'" >> "$BASHRC"
        fi
        echo "ANTHROPIC_API_KEY added to /root/.bashrc."
        SET_ANTHROPIC=1
    fi
fi

read -p "Set DigitalOcean Inference (Gradient) key now? (y/n) [n]: " yn
yn=${yn:-n}
if [[ "${yn,,}" == "y" || "${yn,,}" == "yes" ]]; then
    read -p "Enter your DigitalOcean Gradient model access key: " key
    key=$(strip_quotes "$key")
    if [ -n "$key" ]; then
        if grep -q 'DO_GRADIENT_API_KEY' "$BASHRC" 2>/dev/null; then
            sed -i "s|^export DO_GRADIENT_API_KEY=.*|export DO_GRADIENT_API_KEY='$key'|" "$BASHRC"
        else
            echo "export DO_GRADIENT_API_KEY='$key'" >> "$BASHRC"
        fi
        echo "DO_GRADIENT_API_KEY added to /root/.bashrc."
        SET_GRADIENT=1
    fi
fi

touch "$DONE_FILE"
# Remove this script from .bashrc so it only runs once
sed -i "/$MARKER/d" "$BASHRC"
sed -i '\|/etc/setup_docker_agent.sh|d' "$BASHRC"

echo ""
echo "Setup complete."
if [ -n "$SET_GRADIENT" ]; then
    echo "Run (Gradient): docker-agent run /opt/docker-agent/examples/gradient_agent.yaml"
fi
if [ -n "$SET_OPENAI" ]; then
    echo "Run (OpenAI):  docker-agent run /opt/docker-agent/examples/basic_agent.yaml"
fi
if [ -n "$SET_ANTHROPIC" ]; then
    echo "Run (Anthropic): use an agent YAML that references your Anthropic model"
fi
if [ -z "$SET_GRADIENT$SET_OPENAI$SET_ANTHROPIC" ]; then
    echo "Set an API key (e.g. export DO_GRADIENT_API_KEY=...) then run an example."
    echo "Gradient: docker-agent run /opt/docker-agent/examples/gradient_agent.yaml"
    echo "OpenAI:   docker-agent run /opt/docker-agent/examples/basic_agent.yaml"
fi
echo "Full guide: /opt/docker-agent/README.txt"
echo "********************************************************************************"
echo ""
