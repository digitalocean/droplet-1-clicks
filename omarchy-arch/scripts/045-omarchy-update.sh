#!/bin/bash
#
# Pull the current Omarchy release and system packages from the mirrors. The
# base image is rebuilt only when the ISO changes, so package-only releases
# (4.0.3 -> 4.0.4) arrive through here; without this a Packer-only build
# ships whatever the base froze at install time.
#
# Runs after 030-optimize.sh on purpose: omarchy-update needs the sudoers fix
# (sudo -v must not prompt) and OMARCHY_PATH, both set there.
#
# omarchy-update ends in omarchy-update-restart, a `gum confirm "Updates
# require reboot"` prompt that -y does not suppress and that would otherwise
# hang the build forever. gum reads the controlling terminal rather than
# stdin, so the answer has to arrive through the pty omarchy-update builds
# for itself; script(1) forwards our stdin into it. Declining is all we need:
# the packages are already installed by that point.
set -euo pipefail

# 030-optimize.sh puts OMARCHY_PATH in /etc/environment, which only applies to
# new logins: Packer runs every provisioner over the connection it opened
# before that script existed, so the variable is absent here and
# omarchy-update-dev dies on it under set -u. Set it for this script's
# children rather than depending on the session.
export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

echo "==> Updating Omarchy and system packages (from $(pacman -Q omarchy))"

# Repeat the answer rather than sending it once: the prompt appears minutes
# in, long after a single byte would have been consumed or hit EOF. pipefail
# is off for the pipeline so the feeder's SIGPIPE (141) is not mistaken for
# a failed update, and `|| rc=$?` keeps set -e from aborting before the
# status can be reported.
set +o pipefail
rc=0
( while :; do printf 'n'; sleep 3; done ) | omarchy-update -y || rc=$?
set -o pipefail
if ((rc != 0)); then
  echo "Error: omarchy-update failed (exit ${rc})" >&2
  exit "$rc"
fi

# Set for the reboot we declined; a droplet built from this snapshot must not
# inherit a nag about a reboot that was only ever needed at build time.
rm -f "$HOME/.local/state/omarchy/reboot-required"

# Correct the tag 040 wrote from the template variable: the mirror decides
# what actually shipped, so the installed package is the source of truth and
# template.json's application_version is only a starting value.
INSTALLED=$(pacman -Q omarchy | awk '{print $2}')
sudo sed -i "s/^application_version=.*/application_version=\"${INSTALLED%-*}\"/" \
  /var/lib/digitalocean/application.info

echo "==> Omarchy update OK (${INSTALLED})"
