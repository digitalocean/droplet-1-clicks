#!/bin/bash
# Set or remove DigitalOcean Gradient credentials for Goose (first-login calls this with --first-login).
# Run as root: /opt/goose/configure-gradient-key.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root."
    exit 1
fi

FIRST_LOGIN=0
for _arg in "$@"; do
    case "$_arg" in
        --first-login) FIRST_LOGIN=1 ;;
    esac
done

# shellcheck source=/dev/null
. /opt/goose/lib-goose-gradient.sh

goose_gradient_sync_declarative_json
goose_gradient_migrate_legacy_provider

echo ""
if [ "$FIRST_LOGIN" -eq 1 ]; then
    echo "DigitalOcean Gradient AI (optional)"
    echo "A Goose custom provider is installed: DigitalOcean Gradient (see digitalocean_gradient.json)."
    echo "Leave the key empty to skip; configure or change it later with:  /opt/goose/configure-gradient-key.sh"
else
    echo "DigitalOcean Gradient model access key (Goose provider id: digitalocean_gradient)."
    echo "Create a key in the DigitalOcean control panel (Gen AI / Gradient)."
    echo "Press Enter with an empty key to remove a saved key from this image."
fi
echo ""

if [ "$FIRST_LOGIN" -eq 1 ]; then
    read -r -s -p "Gradient model access key (empty = skip): " GRADIENT_KEY
else
    read -r -s -p "Gradient model access key: " GRADIENT_KEY
fi
echo ""

if [ -z "$GRADIENT_KEY" ]; then
    if [ "$FIRST_LOGIN" -eq 1 ]; then
        rm -f /etc/profile.d/goose-gradient.sh
        echo "Skipped Gradient key. Run /opt/goose/configure-gradient-key.sh when you have a key."
    else
        goose_gradient_remove_env_files
        echo "Removed Gradient key from /etc/profile.d, ~/.bashrc hook, and ~/.config/goose/secrets.yaml."
        echo "GOOSE_PROVIDER / GOOSE_MODEL in config.yaml were not changed; run 'goose configure' if you need to switch providers."
        echo "Unset in this shell: unset DO_GRADIENT_API_KEY"
    fi
    exit 0
fi

goose_gradient_apply_full "$GRADIENT_KEY"
if [ "$FIRST_LOGIN" -eq 1 ]; then
    echo "Gradient configured for Goose: provider digitalocean_gradient, default model minimax-m2.5 (edit GOOSE_MODEL in ~/.config/goose/config.yaml to switch)."
    echo "Key stored in /root/.config/goose/secrets.yaml, /etc/profile.d/goose-gradient.sh, and your shell profile (non-login SSH loads .bashrc)."
else
    echo "Updated Gradient credentials and default Goose provider (digitalocean_gradient / minimax-m2.5 when GOOSE_MODEL was unset)."
    echo "Open a new SSH session or run:  source /etc/profile.d/goose-gradient.sh"
fi
