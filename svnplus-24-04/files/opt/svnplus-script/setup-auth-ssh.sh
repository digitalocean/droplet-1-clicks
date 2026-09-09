#!/bin/bash

if [ ! -f "/etc/profile.d/svnplus.sh" ]; then
    echo "Please run /opt/svnplus-script/setup.sh first!"
    exit 1
fi
source /etc/profile.d/svnplus.sh
echo "Setting up svn+ssh auth."
echo "--------------------------------------------------"

useradd svnplus -d $SVN_ROOT/svnplus
mkdir $SVN_ROOT/svnplus
mkdir $SVN_ROOT/svnplus/.ssh
chmod 700 $SVN_ROOT/svnplus/.ssh
echo V1 > $SVN_ROOT/svnplus/version
touch $SVN_ROOT/svnplus/.ssh/authorized_keys
chmod 600 $SVN_ROOT/svnplus/.ssh/authorized_keys
chown -R svnplus:svnplus $SVN_ROOT/svnplus
usermod -a -G svnusers svnplus
