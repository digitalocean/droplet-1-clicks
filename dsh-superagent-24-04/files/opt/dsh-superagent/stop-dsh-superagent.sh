#!/bin/bash
# Stop DSH Superagent gracefully (running Executors finish their current step; up to 5 minutes).
# A stop is intentional: the hourly check will not restart it until you start it again.
set -euo pipefail
exec systemctl stop dsh-superagent.service
