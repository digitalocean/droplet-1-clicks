#!/bin/bash
clear
echo "----------------------------------------------------------------------------"
echo "This script will configure your Discourse installation"
echo "Please be sure you have the following information to proceed:"
echo "  - Email Address for your Discourse install"
echo "  - Domain/Subdomain to use"
echo "  - Mail server information (SMTP)"
echo ""
echo "After being prompted for these details the Discourse installer will"
echo "download and install the latest version of Discourse and its requirements"
echo "This process will take approximately 10 minutes"
echo "----------------------------------------------------------------------------"
echo "When you are ready to proceed, press Enter"
echo "To cancel setup, press Ctrl+C and this script will be run again on your next login"

read wait
cd /var/discourse

if ./discourse-setup; then
  clear
  echo "Discourse is now installed.  Log into your admin account in a browser to continue"
  echo "configuring Discourse."

  cp -f /etc/skel/.bashrc /root/.bashrc
else
  echo ""
  echo "----------------------------------------------------------------------------"
  echo "The setup script failed with the provided Discourse details"
  echo "It will rerun. Please address the above issues"
  echo "----------------------------------------------------------------------------"
  echo "When you are ready to proceed, press Enter"
  echo "To cancel setup, press Ctrl+C and this script will be run again on your next login"
  read wait
fi
