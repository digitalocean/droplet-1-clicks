#!/bin/bash

gateway_token=$(grep "^OPENCLAW_GATEWAY_TOKEN=" /opt/openclaw.env 2>/dev/null | cut -d'=' -f2)

/opt/openclaw-cli.sh tui --token=${gateway_token}
