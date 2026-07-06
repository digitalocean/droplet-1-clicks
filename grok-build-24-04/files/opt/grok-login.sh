#!/bin/bash

# Streamlined xAI account sign-in for headless droplets.
#
# A droplet has no desktop browser, so the default `grok login` (browser OIDC)
# can't pop one open. This helper uses the RFC 8628 device-code flow instead:
# Grok prints a short URL + code that you open on any device (laptop/phone) to
# authorize. The session token is then saved to ~/.grok/auth.json and refreshed
# automatically.
#
# Note: if this droplet is configured with a DigitalOcean model access key
# (the default), you do NOT need to sign in at all — Grok uses the API key.

[ -d /root/.grok/bin ] && export PATH="/root/.grok/bin:$PATH"

if ! command -v grok >/dev/null 2>&1; then
  echo "grok not found on PATH. Try: /root/.grok/bin/grok login --device-auth"
  exit 1
fi

echo "Starting xAI device-code sign-in (no browser needed on this droplet)..."
echo "Open the URL shown below on any device and enter the code."
echo ""
exec grok login --device-auth
