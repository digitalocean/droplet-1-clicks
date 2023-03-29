#!/bin/bash

systemctl start nfs-kernel-server
systemctl enable nfs-kernel-server

chmod +x /root/local-partition.sh
chmod +x /root/nfs-whitelist.sh	

# add security
echo "y" | ufw enable

systemctl start fail2ban
systemctl enable fail2ban
printf '[sshd]\nenabled = true\nport = 22\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5' | tee -a /etc/fail2ban/jail.local
systemctl restart fail2ban

systemctl enable ufw
ufw limit ssh
