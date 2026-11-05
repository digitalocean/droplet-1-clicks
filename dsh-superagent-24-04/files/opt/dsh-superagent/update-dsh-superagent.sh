#!/bin/bash
# Move DSH Superagent to another commit or tag of the upstream repository.
#
# Usage: sudo /opt/dsh-superagent/update-dsh-superagent.sh <commit-or-tag>
#
# Follows the upstream upgrade procedure: stop gracefully (Executors finish
# their step), back up the database, check out the new revision, install and
# build, then start. If a step fails the service stays stopped; fix the cause
# and run /opt/dsh-superagent/start-dsh-superagent.sh.
set -euo pipefail

REF=${1:-}
if [ -z "$REF" ]; then
    echo "Usage: $0 <commit-or-tag>" >&2
    echo "The image pins 8c32a9dc5d72c033816c6a8110b37f40cf94fba4 (upstream main at build time)." >&2
    exit 64
fi
if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0 $REF" >&2
    exit 1
fi
case "$REF" in
    *[!A-Za-z0-9._/-]*)
        echo "Unsupported commit or tag: $REF" >&2
        exit 64
        ;;
esac

APP_USER=superagent
APP_HOME=/home/superagent
APP_DIR=$APP_HOME/dsh-superagent
STATE_DIR=$APP_HOME/.dsh/state/superagent
BACKUP_DIR=$APP_HOME/backups

as_app() {
    runuser -u "$APP_USER" -- env -i \
        HOME="$APP_HOME" USER="$APP_USER" LOGNAME="$APP_USER" \
        PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 "$@"
}

echo "== stopping DSH Superagent (waits for running Executors)"
systemctl stop dsh-superagent.service

echo "== backing up the database"
install -d -o "$APP_USER" -g "$APP_USER" -m 0700 "$BACKUP_DIR"
stamp=$(date +%Y%m%d-%H%M%S)
for file in orchestrator.sqlite orchestrator.sqlite-wal orchestrator.sqlite-shm; do
    if [ -f "$STATE_DIR/$file" ]; then
        cp -p "$STATE_DIR/$file" "$BACKUP_DIR/$file.$stamp"
    fi
done
chown -R "$APP_USER:$APP_USER" "$BACKUP_DIR"

echo "== checking out ${REF}"
as_app bash -c "cd '$APP_DIR' && git fetch --quiet --tags origin && git -c advice.detachedHead=false checkout --quiet '$REF'"

echo "== installing and building"
as_app bash -c "cd '$APP_DIR' && pnpm install --frozen-lockfile && pnpm build"

echo "== starting DSH Superagent"
systemctl start dsh-superagent.service
/opt/dsh-superagent/status-dsh-superagent.sh || true
