# Offer the DSH Superagent setup wizard on an interactive root login until it has
# completed. Once configured, this does nothing.
if [ "$(id -u)" -eq 0 ] && [ -t 0 ] && [ -x /etc/setup_wizard.sh ] \
    && [ ! -f /home/superagent/.config/dsh-superagent/configured ]; then
    /etc/setup_wizard.sh
fi
