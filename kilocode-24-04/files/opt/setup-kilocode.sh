#!/bin/bash

# Kilo Code first-login setup helper.
# Prompts for a DigitalOcean model access key, then gets out of the way.

SETUP_MARKER="/root/.kilocode_setup_complete"

if [ -f "$SETUP_MARKER" ] && [ "$1" != "--force" ]; then
  if ! grep -q '/opt/setup-kilocode.sh' /root/.bashrc 2>/dev/null; then
    exit 0
  fi
  rm -f "$SETUP_MARKER"
fi

if [ "$1" != "--force" ] && [ -x /opt/apply-digitalocean-token.sh ]; then
  if /opt/apply-digitalocean-token.sh; then
    exit 0
  fi
fi

echo ""
echo "========================================================================"
echo "  Kilo Code CLI Setup"
echo "========================================================================"
echo ""
echo "This droplet can save a DigitalOcean model access key for Kilo Code"
echo "sessions using DIGITALOCEAN_ACCESS_TOKEN."
echo ""
echo "If you do not have a token yet, press Enter to skip setup."
echo "Kilo will start automatically afterward."
echo ""
echo "Create or manage DigitalOcean model access keys at:"
echo "  https://cloud.digitalocean.com/model-studio/manage-keys"
echo ""

old_histfile="${HISTFILE-}"
unset HISTFILE
read -rsp "Enter DIGITALOCEAN_ACCESS_TOKEN (or press Enter to skip): " MODEL_KEY
echo ""
[ -n "${old_histfile:-}" ] && export HISTFILE="$old_histfile"

if [ -z "$MODEL_KEY" ]; then
  echo ""
  echo "No token entered. Skipping DigitalOcean model access key setup."
  echo "You can still run Kilo now:"
  echo "  cd /path/to/your/project && kilo"
  echo ""
  echo "To configure a DigitalOcean model access key later:"
  echo "  export DIGITALOCEAN_ACCESS_TOKEN=your_token"
  echo "  /opt/apply-digitalocean-token.sh"
  touch "$SETUP_MARKER"
  sed -i '/\/opt\/setup-kilocode.sh/d' /root/.bashrc
  exit 0
fi

DIGITALOCEAN_ACCESS_TOKEN="$MODEL_KEY" /opt/apply-digitalocean-token.sh

echo ""
echo "========================================================================"
echo "  Setup complete! Kilo Code CLI is ready to use."
echo ""
echo "  To start:  cd /path/to/your/project && kilo"
echo "  Token env: DIGITALOCEAN_ACCESS_TOKEN"
echo "  Provider:  KILO_PROVIDER_TYPE=digitalocean"
echo "========================================================================"
echo ""
