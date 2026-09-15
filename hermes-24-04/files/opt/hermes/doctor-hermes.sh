#!/bin/bash
# Run Hermes doctor after clearing known npm workspace advisories.
set -euo pipefail

if [ -x /opt/hermes/remediate-npm.sh ]; then
    /opt/hermes/remediate-npm.sh || true
fi

/opt/hermes/hermes-cli.sh doctor "$@"
