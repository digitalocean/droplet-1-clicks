#!/bin/bash
if [ ! -f "/etc/profile.d/svnplus.sh" ]; then
    echo "Please run /opt/svnplus-script/setup.sh first!"
    exit 1
fi
source /etc/profile.d/svnplus.sh
echo "Enter the name for your new svn repository."
echo "--------------------------------------------------"

while true; do
    read -p "Repository name: " repo
    if [ -z "$repo" ];then
        echo "Please provide a valid repository name to continue"
    else
        break;
    fi
done

svnadmin create $SVN_ROOT/repo/$repo
chown -R root:svnusers $SVN_ROOT/repo/$repo
chmod -R g+w $SVN_ROOT/repo/$repo
echo -e "[/]\n" >> $SVN_ROOT/repo/$repo/conf/authz

if id "svnplus" >/dev/null 2>&1; then
    sed -i '/^\[general\]$/a\anon-access=none\nauth-access=write\nauthz-db = authz' $SVN_ROOT/repo/$repo/conf/svnserve.conf
fi

echo -en "\n\n\n"
while true; do
    read -p "Do you want to make the repository available to anonymus users? (y/N): " yn
    yn=${yn:-n}
    case $yn in
        [Yy]* ) echo -e "*=r\n" >> $SVN_ROOT/repo/$repo/conf/authz; echo "Making the repo anonymusly accessable complete!";break;;
        [Nn]* ) echo "Skipping making the repo anonymusly accessable";break;;
        * ) echo "Please answer y or n.";;
    esac
done
