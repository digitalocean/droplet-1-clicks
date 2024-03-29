#!/bin/bash
#
# Scripts in this directory are run during the build process.
# each script will be uploaded to /tmp on your build droplet, 
# given execute permissions and run.  The cleanup process will
# remove the scripts from your build system after they have run
# if you use the build_image task.
#
mkdir /var/discourse
git clone https://github.com/discourse/discourse_docker.git /var/discourse

# Add first-login task
cat >> /root/.bashrc <<EOM
/opt/digitalocean_discourse/setup_discourse.sh
EOM
