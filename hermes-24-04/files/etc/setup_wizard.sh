#!/bin/bash
set -euo pipefail

SETUP_DONE_MARKER=/home/hermes/.hermes/provider-configured

remove_first_login_hook() {
  if [ -f /root/.bashrc ]; then
    sed -i '/chmod +x \/etc\/setup_wizard\.sh/d' /root/.bashrc
    sed -i '/\/etc\/setup_wizard\.sh/d' /root/.bashrc
  fi
}

if [ -f "$SETUP_DONE_MARKER" ]; then
  echo "Hermes Agent is already configured. Skipping first-login setup."
  remove_first_login_hook
  exit 0
fi

if [ ! -x /home/hermes/.local/bin/hermes ]; then
  echo "ERROR: Hermes CLI is not installed at /home/hermes/.local/bin/hermes." >&2
  exit 1
fi

cat <<'EOF'

========================================================================
  Hermes Agent first-login setup
========================================================================

Hermes is installed for the dedicated 'hermes' user.
The setup wizard will configure your model provider, tools, terminal backend,
and optional messaging gateway.

Docs: https://hermes-agent.nousresearch.com/docs/
GitHub: https://github.com/NousResearch/hermes-agent

EOF

su - hermes -c 'cd /home/hermes/workspace && HERMES_HOME=/home/hermes/.hermes /home/hermes/.local/bin/hermes setup'

printf '%s\n' "configured" > "$SETUP_DONE_MARKER"
chown hermes:hermes "$SETUP_DONE_MARKER"
chmod 0600 "$SETUP_DONE_MARKER"

remove_first_login_hook

cat <<'EOF'

Hermes Agent setup finished.

Start chatting:
  hermes

Run diagnostics:
  hermes doctor

EOF
