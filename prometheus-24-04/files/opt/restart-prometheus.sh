#!/bin/bash
set -euo pipefail
systemctl restart prometheus
systemctl restart caddy
systemctl --no-pager --full status prometheus caddy || true
