# Offer to arm the remote desktop on an interactive login (web console or SSH).
#
# The trigger is the absence of the tmpfs password rather than a
# "setup complete" marker, because the password is deliberately not persisted:
# it is missing before first setup AND after every reboot, and in both cases the
# right thing is to ask. Until someone answers, nothing listens on 3389.
#
# Never fires for non-interactive sessions (scp, ssh <cmd>, cloud-init), and
# `|| true` means declining it costs nothing. Users who do not want the desktop
# at all can silence this for good with:
#   sudo touch /etc/hypr-rdp/no-prompt
if [[ $- == *i* ]] && [[ -t 0 ]] &&
   [[ ! -f /run/hypr-rdp/password ]] &&
   [[ ! -f /etc/hypr-rdp/no-prompt ]]; then
  /usr/local/bin/omarchy-droplet-setup || true
fi
