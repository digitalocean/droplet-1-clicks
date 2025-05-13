#!/bin/bash
#
# SVNPlus activation script
#
# This script setup ssh+svn auth
# This is heavily beased on Wordpress 22-04 one click script
# SVN setup is based on https://www.dalbert.net/subversion-security-for-teams/
if [ ! -f "/etc/profile.d/svnplus.sh" ]; then
    echo "----------------------------------------------------------------------------"
    echo "This script will configure your SVNPlus installation"
    echo "----------------------------------------------------------------------------"
    echo "When you are ready to proceed, press Enter"
    echo "To cancel setup, press Ctrl+C and this script will be run again on your next login"

    read wait

    first_dir=$(find /mnt -mindepth 1 -maxdepth 1 -type d | head -n 1)

    if [ -z "$first_dir" ]; then
        first_dir="/opt"
        echo "No directory was found in /mnt, we recommend mounting a Block storage volume"
        echo "to store the repositories and other configuration data"
        echo "Press Ctrl+C and setup volume storage if you want to use that"
    fi

    echo -n "What directory would you like to use as your repository root? [default: $first_dir]: "
    read user_input

    if [ -z "$user_input" ]; then
        repo_root="$first_dir"
    else
        repo_root="$user_input"
    fi

    mkdir "$repo_root/repo"

    sed -i 's/80/3690/g' /etc/apache2/ports.conf
    service apache2 restart
    service nginx restart

    echo -en "\n\n\n"
    while true; do
        read -p "Do you want to configure a domain for your SVNPlus instance? (y/N): " yn
        yn=${yn:-n}
        case $yn in
            [Yy]* ) /opt/svnplus-script/setup-domain.sh;echo "domain setup complete!";break;;
            [Nn]* ) echo "Skipping domain setup";break;;
            * ) echo "Please answer y or n.";;
        esac
    done

    echo -e "export SVN_ROOT=\"$repo_root\"\n" > /etc/profile.d/svnplus.sh
    sudo chmod +x /etc/profile.d/svnplus.sh
    source /etc/profile.d/svnplus.sh

    groupadd svnusers

    echo "SVNPlus Initial setup is done!"
    echo "You can continue configuring your server using this script, or rerun this"
    echo "script from /opt/svnplus-script/setup.sh any time to do additional configuration!"
    first_user=true
    cp -f /etc/skel/.bashrc /root/.bashrc
else
    source /etc/profile.d/svnplus.sh
    echo "----------------------------------------------------------------------------"
    echo "This is the SVNPlus configuration script, the configuration was already done"
    echo "but you can still run configuration scripts using this script"
    echo "----------------------------------------------------------------------------"
    if id "svnplus" >/dev/null 2>&1; then
        echo "svn+ssh auth already configured!"
    fi
    if [ -f "$SVN_ROOT/passwd" ]; then
        echo "https user+password based auth already configured!"
    fi
    repo_dir=$(find $SVN_ROOT/repo -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -z "$repo_dir" ]; then
        echo "No repositories found in $SVN_ROOT/repo."
    else
        echo "Repositories found, to add more please use the /opt/svnplus-script/addrepo.sh script directly"
    fi
    first_user=true
    if id "svnplus" >/dev/null 2>&1; then
        auth_keys_file="$SVN_ROOT/svnplus/.ssh/authorized_keys"
        if [ -s "$SVN_ROOT/svnplus/.ssh/authorized_keys" ]; then
            first_user=false
        fi
    fi
    if [ -s "$SVN_ROOT/passwd" ]; then
        first_user=false
    fi
    if [ "$first_user" ]; then
        echo "No user found."
    else
        echo "User found, to add more please use the /opt/svnplus-script/adduser.sh script directly"
    fi
    echo "----------------------------------------------------------------------------"
    echo "When you are ready to proceed, press Enter"
    echo "To cancel setup, press Ctrl+C and you can rerun this script from /opt/svnplus-script/setup.sh"
    echo "any time to do additional configuration!"
    echo "----------------------------------------------------------------------------"

    read wait
fi

if ! id "svnplus" >/dev/null 2>&1; then
    echo -en "\n\n\n"
    while true; do
        read -p "Do you want to enable svn+ssh key based authentication? (y/N): " yn
        yn=${yn:-n}
        case $yn in
            [Yy]* ) /opt/svnplus-script/setup-auth-ssh.sh; echo "svn+ssh setup complete!";break;;
            [Nn]* ) echo "Skipping svn+ssh auth";break;;
            * ) echo "Please answer y or n.";;
        esac
    done
fi

if [ ! -f "$SVN_ROOT/passwd" ]; then
    echo -en "\n\n\n"
    while true; do
        read -p "Do you want to enable https user+password based authentication? (y/N): " yn
        yn=${yn:-n}
        case $yn in
            [Yy]* ) /opt/svnplus-script/setup-auth-https.sh; echo "https user+password setup complete!";break;;
            [Nn]* ) echo "Skipping https user+password auth";break;;
            * ) echo "Please answer y or n.";;
        esac
    done
fi

if [ -z "$repo_dir" ]; then
    echo -en "\n\n\n"
    while true; do
        read -p "Do you want to add your first repository now? (Y/n): " yn
        yn=${yn:-y}
        case $yn in
            [Yy]* ) /opt/svnplus-script/addrepo.sh; echo "first repository setup complete!";break;;
            [Nn]* ) echo "Skipping first repository setup";break;;
            * ) echo "Please answer y or n.";;
        esac
    done
fi

if [ "$first_user" ]; then
    echo -en "\n\n\n"
    while true; do
        read -p "Do you want to add your first user now? (Y/n): " yn
        yn=${yn:-y}
        case $yn in
            [Yy]* ) /opt/svnplus-script/adduser.sh; echo "first user setup complete!";break;;
            [Nn]* ) echo "Skipping first user setup";break;;
            * ) echo "Please answer y or n.";;
        esac
    done
fi
