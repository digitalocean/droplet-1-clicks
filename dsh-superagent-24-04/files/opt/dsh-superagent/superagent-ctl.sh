#!/bin/bash
# Run the upstream control script (scripts/dsh-superagent) as the superagent user.
#
# The DeepSeek key lives in the superagent user's env file, which is sourced
# here, so the service sees it without the key ever being stored in the image
# or in systemd unit files. Examples:
#   superagent-ctl.sh start
#   superagent-ctl.sh stop
#   superagent-ctl.sh status
#   superagent-ctl.sh --respect-stop restart
set -euo pipefail

APP_USER=superagent
APP_HOME=/home/superagent
CTL=$APP_HOME/dsh-superagent/scripts/dsh-superagent
ENV_FILE=$APP_HOME/.config/dsh-superagent/env

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <start|stop|restart|status> [options]" >&2
    exit 64
fi

exec runuser -u "$APP_USER" -- env -i \
    HOME="$APP_HOME" USER="$APP_USER" LOGNAME="$APP_USER" \
    PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 \
    /bin/bash -c 'set -a; [ -f "$1" ] && . "$1"; set +a; cd "$HOME" && exec "$2" --profile superagent "${@:3}"' \
    _ "$ENV_FILE" "$CTL" "$@"
