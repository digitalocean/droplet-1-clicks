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

echo ""
echo "********************************************************************************"
echo "  Docker Agent – First-login setup"
echo "********************************************************************************"
echo ""
echo "Optional: save API keys to /root/.bashrc. Then: source /root/.bashrc"
echo "See /opt/docker-agent/README.txt for key order, URLs, and run examples."
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
    fi
fi

read -p "Set GOOGLE_API_KEY now? (y/n) [n]: " yn
yn=${yn:-n}
if [[ "${yn,,}" == "y" || "${yn,,}" == "yes" ]]; then
    read -p "Enter your GOOGLE_API_KEY: " key
    key=$(strip_quotes "$key")
    if [ -n "$key" ]; then
        if grep -q 'GOOGLE_API_KEY' "$BASHRC" 2>/dev/null; then
            sed -i "s|^export GOOGLE_API_KEY=.*|export GOOGLE_API_KEY='$key'|" "$BASHRC"
        else
            echo "export GOOGLE_API_KEY='$key'" >> "$BASHRC"
        fi
        echo "GOOGLE_API_KEY added to /root/.bashrc."
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
    fi
fi

touch "$DONE_FILE"
# Remove this script from .bashrc so it only runs once
sed -i "/$MARKER/d" "$BASHRC"
sed -i '\|/etc/setup_docker_agent.sh|d' "$BASHRC"

echo ""
echo "Setup complete. Full guide (keys, run commands, order): /opt/docker-agent/README.txt"
echo "********************************************************************************"
echo ""
