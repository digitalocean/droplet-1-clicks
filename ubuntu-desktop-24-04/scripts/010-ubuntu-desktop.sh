#!/bin/bash
#
# Scripts in this directory are run during the build process.
# each script will be uploaded to /tmp on your build droplet, 
# given execute permissions and run.  The cleanup process will
# remove the scripts from your build system after they have run
# if you use the build_image task.
#

# open default VNC port
ufw allow 5900
# open default RDP port
ufw allow 3389
# Add first-login task
cat >> /root/.bashrc <<EOM
/opt/digitalocean_desktop/setup_vnc.sh
EOM

chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Reinstall droplet-agent at boot (it is purged by the cleanup script and
# cloud-init's reinstall is unreliable on the desktop image)
chmod +x /opt/digitalocean_desktop/install_droplet_agent.sh
systemctl enable droplet-agent-install
