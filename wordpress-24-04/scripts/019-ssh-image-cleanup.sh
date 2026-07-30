#!/bin/sh

# Packer authenticates with SSH keys, so cloud-init may bake
# PasswordAuthentication no into this drop-in. Leave it out of the
# snapshot so first-boot cloud-init can set the correct value for
# password-created Droplets (needed for Web Console login).
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
