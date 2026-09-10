#!/bin/bash
#
# fail2ban with an sshd jail (journal backend; Arch has no auth.log).
set -euo pipefail

echo "==> Configuring fail2ban"
sudo cp /tmp/build-files/etc/fail2ban/jail.local /etc/fail2ban/jail.local
sudo systemctl enable fail2ban.service

echo "==> fail2ban OK"
