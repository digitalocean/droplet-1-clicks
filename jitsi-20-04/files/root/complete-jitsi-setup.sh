#!/bin/bash

# Scripts in this directory will be executed by cloud-init on the first boot of droplets
# created from your image.  Things like generating passwords, configuration requiring IP address
# or other items that will be unique to each instance should be done in scripts here.

printf "\n-------------------------\nUpdating the system\n-------------------------\n"

apt-get update
apt-get upgrade

printf "\n-------------------------\nConfiguring Jitsi for your domain\n-------------------------\n"

apt-get -y install jicofo jitsi-meet jitsi-meet-prosody jitsi-meet-turnserver jitsi-meet-web jitsi-meet-web-config jitsi-videobridge2

bash /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

# update prosody to use internal user management
for f in /etc/prosody/conf.avail/*.cfg.lua; do
    # ignore default prosody configuration files
	if [[ "$f" == */example.com.cfg.lua ]] || [[ "$f" == */jaas.cfg.lua ]] || [[ "$f" == */localhost.cfg.lua ]]; then
		continue
	fi
	printf "processing prosody conf file: ${f}\n"
	sed -i "s/authentication = \".*\"/authentication=\"internal_hashed\"/g" $f;
done

systemctl restart prosody
systemctl restart jicofo
systemctl restart jitsi-videobridge2