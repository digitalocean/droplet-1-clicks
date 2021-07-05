#!/bin/sh

sed -e "s|upload_max_filesize.*|upload_max_filesize = 16M|g" \
    -e "s|post_max_size.*|post_max_size = 16M|g" \
    -e "s|max_execution_time.*|max_execution_time = 60|g" \
    -i /etc/php/8.0/apache2/php.ini
