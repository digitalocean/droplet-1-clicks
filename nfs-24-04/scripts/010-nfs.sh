#!/bin/bash
set -euo pipefail

systemctl enable nfs-kernel-server
systemctl start nfs-kernel-server

chmod +x /root/local-partition.sh

# Allow SSH before enabling UFW so Packer's communicator is not dropped mid-build.
ufw limit ssh
ufw --force enable
systemctl enable ufw

systemctl enable fail2ban
printf '[sshd]\nenabled = true\nport = 22\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5\n' | tee /etc/fail2ban/jail.local
systemctl restart fail2ban
