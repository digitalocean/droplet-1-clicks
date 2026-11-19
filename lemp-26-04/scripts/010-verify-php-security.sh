#!/bin/bash
# Bake-time checks after PHP packages are installed.

set -euo pipefail

PHP_MIN="8.5.13"
FCGI_SOCKET="unix:/run/php/php8.5-fpm.sock"

version_ge() {
    local sorted lower
    sorted="$(printf '%s\n%s\n' "$1" "$2" | sort -V)"
    lower="${sorted%%$'\n'*}"
    [ "${lower}" = "$2" ]
}

php_actual="$(php -r 'echo PHP_VERSION;')"
if ! version_ge "${php_actual}" "${PHP_MIN}"; then
    echo "Build failed: PHP ${php_actual} is below minimum ${PHP_MIN} (need 2026-11-19 security release)" >&2
    exit 1
fi
echo "PHP ${php_actual} meets minimum ${PHP_MIN}"

php_fpm_ver="$(dpkg-query -W -f='${Version}' php8.5-fpm 2>/dev/null || true)"
if [ -z "${php_fpm_ver}" ]; then
    echo "Build failed: php8.5-fpm package is not installed" >&2
    exit 1
fi
echo "php8.5-fpm package version: ${php_fpm_ver}"

nginx_site="/etc/nginx/sites-available/digitalocean"
if [ ! -f "${nginx_site}" ]; then
    echo "Build failed: missing ${nginx_site}" >&2
    exit 1
fi
fcgi_pass_line="$(grep -E '^\s*fastcgi_pass\s+' "${nginx_site}" || true)"
if [ -z "${fcgi_pass_line}" ]; then
    echo "Build failed: no fastcgi_pass directive in ${nginx_site}" >&2
    exit 1
fi
case "${fcgi_pass_line}" in
    *"${FCGI_SOCKET}"*)
        echo "Nginx fastcgi_pass matches expected socket ${FCGI_SOCKET}"
        ;;
    *)
        echo "Build failed: fastcgi_pass does not use ${FCGI_SOCKET}: ${fcgi_pass_line}" >&2
        exit 1
        ;;
esac

mapfile -t _listen_lines < <(grep -E '^\s*listen\s*=' /etc/php/8.5/fpm/pool.d/www.conf 2>/dev/null || true)
pool_conf="${_listen_lines[0]:-}"
if [ -n "${pool_conf}" ]; then
    case "${pool_conf}" in
        */php8.5-fpm.sock*)
            echo "PHP-FPM pool listen matches php8.5-fpm.sock (${pool_conf})"
            ;;
        *)
            echo "WARNING: unexpected PHP-FPM listen (${pool_conf}); Nginx expects php8.5-fpm.sock" >&2
            exit 1
            ;;
    esac
fi

nginx_ver="$(dpkg-query -W -f='${Package} ${Version}\n' nginx)"
mysql_ver="$(dpkg-query -W -f='${Package} ${Version}\n' mysql-server)"
echo "Stack packages (unchanged sources expected):"
echo "${nginx_ver}"
echo "${mysql_ver}"

for pkg in nginx mysql-server; do
    pkg_ver="$(dpkg-query -W -f='${Version}' "${pkg}")"
    case "${pkg_ver}" in
        *deb.sury.org*|*+ondrej*)
            echo "Build failed: ${pkg} appears to come from ondrej/sury (${pkg_ver})" >&2
            exit 1
            ;;
    esac
done

echo "LEMP PHP security bake-time checks passed."