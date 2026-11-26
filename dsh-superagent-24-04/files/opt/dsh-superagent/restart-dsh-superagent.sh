#!/bin/bash
# Restart DSH Superagent: graceful stop, then start. Running Assignments are
# recovered with notes after the restart.
set -euo pipefail
exec systemctl restart dsh-superagent.service
