#!/bin/sh

# Configure PHP for FPM (used with Caddy)
sed -e "s|upload_max_filesize.*|upload_max_filesize = 16M|g" \
    -e "s|post_max_size.*|post_max_size = 16M|g" \
    -e "s|max_execution_time.*|max_execution_time = 60|g" \
    -i /etc/php/8.3/fpm/php.ini

# Also configure CLI version for WP-CLI
sed -e "s|upload_max_filesize.*|upload_max_filesize = 16M|g" \
    -e "s|post_max_size.*|post_max_size = 16M|g" \
    -e "s|max_execution_time.*|max_execution_time = 60|g" \
    -i /etc/php/8.3/cli/php.ini
