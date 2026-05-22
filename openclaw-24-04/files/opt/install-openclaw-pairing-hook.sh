#!/bin/bash
# Append first-login Control UI pairing hook to /root/.bashrc (idempotent).
set -euo pipefail

MARKER='openclaw-24-04-control-ui-pairing'

if grep -q "$MARKER" /root/.bashrc 2>/dev/null; then
    exit 0
fi

cat >>/root/.bashrc <<'EOM'

# openclaw-24-04-control-ui-pairing BEGIN
[ -x /opt/openclaw-control-ui-pairing.sh ] && /opt/openclaw-control-ui-pairing.sh
# openclaw-24-04-control-ui-pairing END
EOM

exit 0
