#!/bin/bash
set -euo pipefail
systemctl start prometheus
systemctl start caddy
systemctl --no-pager --full status prometheus caddy || true
