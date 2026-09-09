#!/bin/bash
if [ ! -f "/etc/profile.d/svnplus.sh" ]; then
    echo "Please run /opt/svnplus-script/setup.sh first!"
    exit 1
fi
source /etc/profile.d/svnplus.sh
echo "Enter the name for your new svn repository."
echo "--------------------------------------------------"

nginxconfigs=$(find /etc/nginx/sites-enabled/ | wc -l)
if [[ "$nginxconfigs" == 2 ]]; then
    address=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1 | head -n 1)
    sed -i "s/%DOMAIN%/$address/g"  /etc/nginx/sites-available/nginx-repo-forward.conf
    ln -s /etc/nginx/sites-available/nginx-repo-forward.conf /etc/nginx/sites-enabled/
    service nginx restart
fi
sed -i "s:%SVN_ROOT%:$SVN_ROOT:g"  /etc/apache2/sites-available/webdav.conf
ln -s /etc/apache2/sites-available/webdav.conf /etc/apache2/sites-enabled/

usermod -a -G svnusers www-data
a2enmod auth_digest
service apache2 restart

touch $SVN_ROOT/passwd
