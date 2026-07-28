
# kilocode-openrouter-24-04-first-login BEGIN
if [ ! -f /root/.kilocode_first_login_complete ]; then
  [ -f /etc/profile.d/kilocode-openrouter.sh ] && . /etc/profile.d/kilocode-openrouter.sh
  /opt/setup-kilocode-openrouter.sh
  [ -f /etc/profile.d/kilocode-openrouter.sh ] && . /etc/profile.d/kilocode-openrouter.sh
  touch /root/.kilocode_first_login_complete
  kilo
fi
# kilocode-openrouter-24-04-first-login END
