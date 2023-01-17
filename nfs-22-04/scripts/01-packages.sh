#!/bin/bash

apt-get -qqy install jq

sleep 10
apt-get -qqy install nfs-kernel-server
systemctl start nfs-kernel-server
systemctl enable nfs-kernel-server

# install Digital Ocean agent
#sleep 10
#curl -sSL https://repos.insights.digitalocean.com/install.sh | bash

# Update the scripts in the root folder
chmod +x /root/local-partition.sh
chmod +x /root/nfs-whitelist.sh	
chmod +x /root/setup-doctl.sh

# add security
echo "y" | ufw enable
sleep 10
apt-get -qqy install fail2ban
systemctl start fail2ban
systemctl enable fail2ban
printf '[sshd]\nenabled = true\nport = 22\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5' | tee -a /etc/fail2ban/jail.local
systemctl restart fail2ban

# open ssh port
sleep 10
systemctl enable ufw
ufw allow ssh
#ufw allow 2049

# Delete the log files
sleep 3
\rm -f /var/log/auth.log
\rm -f /var/log/droplet-agent.update.log
\rm -f /var/log/kern.log 
\rm -f /var/log/ufw.log

# Delete the DO agent, if any
sudo apt-get -qqy  purge droplet-agent
sleep 3
