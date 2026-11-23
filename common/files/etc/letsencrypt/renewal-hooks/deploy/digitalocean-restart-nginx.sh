#!/bin/sh
# CVE-2026-123007: changing listen/http2 requires full nginx restart, not reload.
set -e
if command -v systemctl >/dev/null 2>&1; then
  systemctl restart nginx.service >/dev/null 2>&1 || true
fi
