#!/bin/bash
# Show DSH Superagent status and how to open its panel.
#
# The runtime's exit codes: 0 normal, 1 not running or not answering (a restart
# may fix it), 2 a part reports an error (a restart will not), 3 waiting for setup.
set -uo pipefail

APP_HOME=/home/superagent
LOG_DIR=$APP_HOME/dsh-superagent/.artifacts

systemctl --no-pager --lines=0 status dsh-superagent.service 2>/dev/null | head -n 3
echo

/opt/dsh-superagent/superagent-ctl.sh status
rc=$?
echo
echo "Exit code: ${rc} (0 normal, 1 not running, 2 part error, 3 waiting for setup)"

latest=$(ls -t "$LOG_DIR"/dsh-superagent-superagent-*.log 2>/dev/null | head -n 1)
url=""
if [ -n "$latest" ]; then
    url=$(grep -o 'http://127.0.0.1:[0-9]*/?token=[^[:space:]]*' "$latest" | tail -n 1)
fi

echo
echo "Panel: open an SSH tunnel from your computer, then the URL below:"
echo "  ssh -L 3082:127.0.0.1:3082 root@<droplet-ip>"
if [ -n "$url" ]; then
    echo "  ${url}"
else
    echo "  (no token yet: start DSH Superagent first)"
fi
echo "The token changes each time DSH Superagent starts."
exit "$rc"
