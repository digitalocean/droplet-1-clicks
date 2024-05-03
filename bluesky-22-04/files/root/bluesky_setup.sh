#!/bin/bash

echo "This script will start the BlueSky PDS installation"
echo "--------------------------------------------------"
echo "This setup requires a domain name.  If you do not have one yet, you may"
echo "cancel this setup, press Ctrl+C.  This script will run again on your next login"
echo "--------------------------------------------------"
echo "Enter the domain name for your new BlueSky PDS"
echo "(ex. example.org or test.example.org) do not include www or http/s"
echo "--------------------------------------------------"

wget https://raw.githubusercontent.com/bluesky-social/pds/main/installer.sh
sudo bash installer.sh

cp /etc/skel/.bashrc /root

echo "Installation complete. Configure your BlueSky app with generated handle data."
