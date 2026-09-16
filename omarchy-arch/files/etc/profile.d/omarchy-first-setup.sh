# Launch the Omarchy droplet setup assistant on the first interactive login
# (web console or SSH). Quiet forever once setup completes; never triggers
# for non-interactive sessions (scp, ssh <cmd>, cloud-init).
if [[ $- == *i* ]] && [[ -t 0 ]] && [[ ! -f /var/lib/digitalocean/omarchy_setup_complete ]]; then
  /usr/local/bin/omarchy-droplet-setup || true
fi
