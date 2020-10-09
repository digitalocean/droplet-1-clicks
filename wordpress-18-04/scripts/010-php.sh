#!/bin/sh

update-alternatives --set php /usr/bin/php7.4

sed -e "s|upload_max_filesize.*|upload_max_filesize = 16M|g" \
    -e "s|post_max_size.*|post_max_size = 16M|g" \
    -e "s|max_execution_time.*|max_execution_time = 60|g" \
    -i /etc/php/7.4/apache2/php.ini