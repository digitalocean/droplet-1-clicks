#!/bin/sh

################################
## PART: Write the application tag
##
## vi: syntax=sh expandtab ts=4

build_date=$(date +%Y-%m-%d)
distro="$(lsb_release -s  -i)"
distro_release="$(lsb_release -s  -r)"
distro_codename="$(lsb_release -s -c)"
distro_arch="$(uname -m)"

# Read version from core (no wp-config.php at build time — secrets land in 001_onboot)
if [ -f /var/www/wordpress/wp-includes/version.php ]; then
  application_version=$(sed -n "s/.*\$wp_version = '\\([^']*\\)'.*/\\1/p" \
    /var/www/wordpress/wp-includes/version.php | head -1)
elif [ -x /usr/bin/wp ] && [ -d /var/www/wordpress ]; then
  application_version=$(wp core version --allow-root --path=/var/www/wordpress 2>/dev/null || true)
fi

phpmyadmin_version=""
if [ -f /usr/share/phpmyadmin/libraries/classes/Version.php ]; then
  phpmyadmin_version=$(sed -n "s/.*public const VERSION = '\\([^']*\\)'.*/\\1/p" \
    /usr/share/phpmyadmin/libraries/classes/Version.php | head -1)
fi

cat >> /var/lib/digitalocean/application.info <<EOM
application_name="${application_name}"
build_date="${build_date}"
distro="${distro}"
distro_release="${distro_release}"
distro_codename="${distro_codename}"
distro_arch="${distro_arch}"
application_version="${application_version}"
phpmyadmin_version="${phpmyadmin_version}"
EOM
