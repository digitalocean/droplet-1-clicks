#!/bin/bash
# Do not clear here — PAM already printed /etc/update-motd.d/99-one-click.
echo "----------------------------------------------------------------------------"
echo "This script will configure your MariaDB installation"
echo "----------------------------------------------------------------------------"
echo "When you are ready to proceed, press Enter"
echo "To cancel setup, press Ctrl+C and this script will be run again on your next login"

read wait

if mysql_secure_installation; then
  # Drop the first-login hook before re-printing MOTD so copy matches post-setup state.
  cp -f /etc/skel/.bashrc /root/.bashrc
  clear
  if [ -x /etc/update-motd.d/99-one-click ]; then
    /etc/update-motd.d/99-one-click
  fi
  echo "MariaDB is now installed. Enjoy it!"
else
  echo ""
  echo "----------------------------------------------------------------------------"
  echo "The setup process failed"
  echo "It will rerun. Please address the above issues"
  echo "----------------------------------------------------------------------------"
  echo "When you are ready to proceed, press Enter"
  echo "To cancel setup, press Ctrl+C and this script will be run again on your next login"
  read wait
fi
