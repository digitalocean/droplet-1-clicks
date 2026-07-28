#!/bin/bash

# Kilo Code (OpenRouter) first-login setup helper.
# Prompts for an OpenRouter API key, then gets out of the way.

SETUP_MARKER="/root/.kilocode_setup_complete"

if [ -f "$SETUP_MARKER" ] && [ "$1" != "--force" ]; then
  if ! grep -q '/opt/setup-kilocode-openrouter.sh' /root/.bashrc 2>/dev/null; then
    exit 0
  fi
  rm -f "$SETUP_MARKER"
fi

if [ "$1" != "--force" ] && [ -x /opt/apply-openrouter-token.sh ]; then
  if /opt/apply-openrouter-token.sh; then
    exit 0
  fi
fi

echo ""
echo "========================================================================"
echo "  Kilo Code CLI Setup (OpenRouter Agent)"
echo "========================================================================"
echo ""
echo "This droplet runs Kilo Code as an OpenRouter coding agent:"
echo "  https://openrouter.ai/apps/kilo-code"
echo ""
echo "Save an OpenRouter API key for Kilo sessions using OPENROUTER_API_KEY."
echo ""
echo "If you do not have a key yet, press Enter to skip setup."
echo "Kilo will start automatically afterward."
echo ""
echo "Create or manage OpenRouter API keys at:"
echo "  https://openrouter.ai/keys"
echo ""

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rp "Enter OPENROUTER_API_KEY (or press Enter to skip): " MODEL_KEY
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "No key entered. Skipping OpenRouter API key setup."
  echo "You can still run Kilo now:"
  echo "  cd /path/to/your/project && kilo"
  echo ""
  echo "To configure an OpenRouter API key later:"
  echo "  export OPENROUTER_API_KEY=your_key"
  echo "  /opt/apply-openrouter-token.sh"
  touch "$SETUP_MARKER"
  sed -i '/\/opt\/setup-kilocode-openrouter.sh/d' /root/.bashrc
  exit 0
fi

OPENROUTER_API_KEY="$MODEL_KEY" /opt/apply-openrouter-token.sh

echo ""
echo "========================================================================"
echo "  Setup complete! Kilo Code is ready as an OpenRouter agent."
echo ""
echo "  App page:  https://openrouter.ai/apps/kilo-code"
echo "  To start:  cd /path/to/your/project && kilo"
echo "  Token env: OPENROUTER_API_KEY"
echo "  Provider:  KILO_PROVIDER_TYPE=openrouter"
echo "  Config:    /root/.config/kilo/kilo.jsonc"
echo "========================================================================"
echo ""
