#!/bin/bash
# Post-install layout for nginx.org packages on Ubuntu 1-clicks (sites-enabled, no default site).
set -euo pipefail

nginx_org_ensure_sites_enabled_layout() {
  install -d -m 0755 /etc/nginx/sites-available /etc/nginx/sites-enabled
  rm -f /etc/nginx/conf.d/default.conf
  if [ -f /etc/nginx/nginx.conf ] && ! grep -qE 'sites-enabled' /etc/nginx/nginx.conf; then
    sed -i '/include[[:space:]]\+\/etc\/nginx\/conf\.d\/\*\.conf;/a\    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
  fi
  if command -v nginx >/dev/null 2>&1 && [ -f /etc/nginx/nginx.conf ]; then
    nginx -t
  fi
}

nginx_org_install_regression_checks() {
  if dpkg -l apache2 2>/dev/null | awk '/^ii/ {found=1} END {exit !found}'; then
    echo "regression: apache2 must not be installed (conflicts with nginx on :80)" >&2
    return 1
  fi
  if ! command -v certbot >/dev/null 2>&1; then
    echo "regression: certbot must be installed after nginx.org swap" >&2
    return 1
  fi
  if [ ! -f /etc/nginx/nginx.conf ]; then
    echo "regression: missing /etc/nginx/nginx.conf" >&2
    return 1
  fi
  if [ -f /etc/nginx/conf.d/default.conf ]; then
    echo "regression: /etc/nginx/conf.d/default.conf must be removed" >&2
    return 1
  fi
  if ! grep -qE 'sites-enabled' /etc/nginx/nginx.conf; then
    echo "regression: nginx.conf must include /etc/nginx/sites-enabled/*" >&2
    return 1
  fi
  if command -v nginx >/dev/null 2>&1; then
    nginx -t
  fi
  return 0
}