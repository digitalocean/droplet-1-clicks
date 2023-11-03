#!/bin/bash
clear
echo "----------------------------------------------------------------------------"
echo "This script will configure your MariaDB installation"
echo "----------------------------------------------------------------------------"
echo "When you are ready to proceed, press Enter"
echo "To cancel setup, press Ctrl+C and this script will be run again on your next login"

read wait

if mysql_secure_installation; then
  clear
  echo "MariaDB is now installed. Enjoy it!"

  cp -f /etc/skel/.bashrc /root/.bashrc
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
