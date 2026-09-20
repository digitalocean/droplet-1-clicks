#!/bin/bash

if [ ! -f "/etc/profile.d/svnplus.sh" ]; then
    echo "Please run /opt/svnplus-script/setup.sh first!"
    exit 1
fi
source /etc/profile.d/svnplus.sh
echo "Enter the credentials for your new svn user."
echo "--------------------------------------------------"

function svn_account(){
    while [ -z $username ]
    do
        echo -en "\n"
        read -p  "Username: " username
    done

    if id "svnplus" >/dev/null 2>&1; then
        while [ -z "$publickey" ]
        do
            echo -en "\n"
            read -r -p "Public key: " publickey
        done
    fi

    if [ -f "$SVN_ROOT/passwd" ]; then
        while [ -z $password ]
        do
            echo -en "\n"
            read -r -p "Password: " password
        done
    fi
}

echo "use puttygen and paste the public key without the beginging and the end"
echo "so from ssh-rsa AAAB...ABC rsa-key-2025-0509 only paste the AAAB...ABC part"

svn_account

while true
do
    echo -en "\n"
    read -p "Is the information correct? [Y/n] " confirmation
    confirmation=${confirmation,,}
    if [[ "${confirmation}" =~ ^(yes|y)$ ]] || [ -z $confirmation ]
    then
      break
    else
      unset publickey username confirmation
      svn_account
    fi
done

if [ -f "$SVN_ROOT/passwd" ]; then
    realm="SVNPlus Subversion repository"
    digest="$( printf "%s:%s:%s" "$username" "$realm" "$password" | md5sum | awk '{print $1}' )"
    printf "%s:%s:%s\n" "$username" "$realm" "$digest" >> $SVN_ROOT/passwd
fi

repos=$(find $SVN_ROOT/repo -mindepth 1 -maxdepth 1 -type d | wc -l)
if [[ "$repos" == 1 ]]; then
    echo "we've found one repository and added the user with RW privileges to that"
    repopath=$(find $SVN_ROOT/repo -mindepth 1 -maxdepth 1 -type d)
    echo "at $repopath/conf/authz and $SVN_ROOT/svnplus/.ssh/authorized_keys"
    echo $reponame
    echo -e "$username=rw\n" >> $repopath/conf/authz

    if id "svnplus" >/dev/null 2>&1; then
        echo "command=\"svnserve -r $repopath -t --tunnel-user=$username\",no-port-forwarding,no-agent-forwarding,no-pty,no-X11-forwarding $publickey" >> $SVN_ROOT/svnplus/.ssh/authorized_keys
    fi
else
    if id "svnplus" >/dev/null 2>&1; then
        echo "multiple repositories found, please add the following line to  $SVN_ROOT/svnplus/.ssh/authorized_keys with the correct repository path"
        echo "command=\"svnserve -r $REPOPATH% -t --tunnel-user=$username\",no-port-forwarding,no-agent-forwarding,no-pty,no-X11-forwarding $publickey"
    fi

    echo "in order for the user to have privileges to a repository, you"
    echo "have to add the user to the authz file located at"
    echo "$SVN_ROOT/repo/YOURREPONAME/conf/authz at the end"
    echo "$username=rw"
fi
