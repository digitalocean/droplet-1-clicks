#!/bin/bash
#
# Scripts in this directory are run during the build process.
# each script will be uploaded to /tmp on your build droplet,
# given execute permissions and run.  The cleanup process will
# remove the scripts from your build system after they have run
# if you use the build_image task.
#

chmod +x /opt/digitalocean_clickhouse/setup_password.sh
chmod +x /var/lib/cloud/scripts/per-instance/001_onboot

# Enable on boot; password + start happen in 001_onboot (not interactive .bashrc).
systemctl enable clickhouse-server
