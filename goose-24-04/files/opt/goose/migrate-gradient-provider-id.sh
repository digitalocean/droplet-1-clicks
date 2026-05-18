#!/bin/bash
# Refresh Gradient declarative JSON from /opt/goose and fix legacy GOOSE_PROVIDER=kimi.
# Run as root after updating /opt/goose from a newer 1-Click build.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root."
    exit 1
fi

# shellcheck source=/dev/null
. /opt/goose/lib-goose-gradient.sh

goose_gradient_sync_declarative_json
goose_gradient_migrate_legacy_provider

echo "Done. Declarative JSON refreshed under /root/.config/goose/custom_providers/ when available."
echo "If GOOSE_PROVIDER was kimi it is now digitalocean_gradient. Run: goose --help"
