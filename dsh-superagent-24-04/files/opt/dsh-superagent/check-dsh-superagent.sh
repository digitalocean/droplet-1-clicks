#!/bin/bash
# Hourly check (dsh-superagent-check.timer). Restarts DSH Superagent only when it
# stopped unexpectedly (status exit 1). An intentional stop is respected.
# Exit 2 (a part reports an error) and 3 (waiting for setup) are logged, not
# fixed: a restart does not resolve them.
set -uo pipefail

CTL=/opt/dsh-superagent/superagent-ctl.sh

"$CTL" status > /dev/null 2>&1
code=$?

case "$code" in
    0)
        exit 0
        ;;
    1)
        echo "DSH Superagent is not running; restarting unless it was stopped on purpose."
        "$CTL" --respect-stop restart
        recovered=$?
        echo "Restart finished with exit code ${recovered}."
        exit "$recovered"
        ;;
    2)
        echo "DSH Superagent reports a part error that a restart does not fix; see status-dsh-superagent.sh."
        exit 0
        ;;
    3)
        echo "DSH Superagent is waiting for setup; run /etc/setup_wizard.sh."
        exit 0
        ;;
    *)
        echo "Unexpected status exit code ${code}."
        exit "$code"
        ;;
esac
