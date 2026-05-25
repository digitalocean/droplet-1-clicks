#!/bin/bash
# Run Hermes as the dedicated hermes user while preserving arguments.

HERMES_USER=${HERMES_USER:-hermes}
HERMES_BIN=${HERMES_BIN:-/home/hermes/.local/bin/hermes}
HERMES_HOME=${HERMES_HOME:-/home/hermes/.hermes}

if [ ! -x "$HERMES_BIN" ]; then
    echo "Hermes CLI not found at $HERMES_BIN" >&2
    exit 1
fi

if [ "$(id -un)" = "$HERMES_USER" ]; then
    export HERMES_HOME
    exec "$HERMES_BIN" "$@"
fi

cmd="HERMES_HOME=$(printf '%q' "$HERMES_HOME") $(printf '%q' "$HERMES_BIN")"
for arg in "$@"; do
    cmd+=" $(printf '%q' "$arg")"
done

exec su - "$HERMES_USER" -c "$cmd"
