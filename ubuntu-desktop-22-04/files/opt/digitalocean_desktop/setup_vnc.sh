#!/bin/bash

VNCPASSWORD=$(base64 < /dev/urandom | head -c8)
USER="user"
USERPASSWORD=$(base64 < /dev/urandom | head -c8)

echo "Ubuntu-desktop is now installed and configured. Enjoy it!"
echo ""
echo "----------------------------------------------------------------------------"
echo "Your VNC password is \"$VNCPASSWORD\". To update it you can run:"
echo "x11vnc -storepasswd %NEW_PASSWORD% /home/$USER/.vnc/passwd"
echo "Using XServer from root account is not recommended, so user \"$USER\" is created with password \"$USERPASSWORD\""
echo "To change user's password execute 'passwd ${USER}'"
echo "Raw generated authentication data is stored in '/root/.digitalocean_passwords'"
echo "----------------------------------------------------------------------------"
echo "Ubuntu-Desktop is starting, please wait about 2-3 minutes until console is unblocked"

cat >> /root/.digitalocean_passwords <<EOM
VNC_PASSWORD=$VNCPASSWORD
USER=$USER
USER_PASSWORD=$USERPASSWORD
EOM

adduser --gecos "" --disabled-password $USER
chpasswd <<<"$USER:$USERPASSWORD"

sudo -u $USER mkdir /home/user/.vnc
x11vnc -storepasswd $VNCPASSWORD /home/$USER/.vnc/passwd

systemctl enable x11vnc
systemctl enable sddm
systemctl restart sddm
systemctl restart x11vnc

cp -f /etc/skel/.bashrc /root/.bashrc
