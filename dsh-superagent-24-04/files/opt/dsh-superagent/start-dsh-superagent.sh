#!/bin/bash
# Start DSH Superagent. Waits for the runtime to answer, then reports setup needs.
set -euo pipefail
exec systemctl start dsh-superagent.service
