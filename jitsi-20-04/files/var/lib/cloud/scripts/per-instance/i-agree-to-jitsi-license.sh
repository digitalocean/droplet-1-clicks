#!/bin/bash

# Scripts in this directory will be executed by cloud-init on the first boot of droplets
# created from your image.  Things like generating passwords, configuration requiring IP address
# or other items that will be unique to each instance should be done in scripts here.

printf "\n-------------------------\nUpdating the system\n-------------------------\n"

apt-get update
apt-get upgrade

printf "\n-------------------------\nConfiguring Jitsi for your domain\n-------------------------\n"

echo "Have you already pointed a domain to your droplet in DigitalOcean's dashboard?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) apt-get -y install jicofo jitsi-meet jitsi-meet-prosody jitsi-meet-turnserver jitsi-meet-web jitsi-meet-web-config jitsi-videobridge2;
        bash /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh break;;
        No ) exit;;
    esac
done

