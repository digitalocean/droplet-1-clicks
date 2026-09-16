#!/bin/bash
#
# fail2ban: sshd jail (journal backend; Arch has no auth.log) plus
# caddy-auth for brute-force of the public desktop/https password.
set -euo pipefail

echo "==> Configuring fail2ban"
sudo pacman -S --noconfirm --needed fail2ban 2>&1 | tail -1
sudo cp /tmp/build-files/etc/fail2ban/jail.local /etc/fail2ban/jail.local
sudo install -D -m 644 /tmp/build-files/etc/fail2ban/filter.d/caddy-auth.conf \
  /etc/fail2ban/filter.d/caddy-auth.conf
sudo systemctl enable fail2ban.service

# fail2ban 1.1.1 crashes on Python 3.14 (asyncore accept() may return None;
# upstream fail2ban#3846 area). Apply the one-line guard until the Arch
# package ships a fixed release; a package update simply overwrites this.
AS=$(ls /usr/lib/python3.*/site-packages/fail2ban/server/asyncserver.py 2>/dev/null | head -1)
if [[ -n $AS ]] && ! grep -q "_res is None" "$AS"; then
  sudo python3 - "$AS" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = "\t\ttry:\n\t\t\tconn, addr = self.accept()"
new = "\t\ttry:\n\t\t\t_res = self.accept()\n\t\t\tif _res is None:\n\t\t\t\treturn\n\t\t\tconn, addr = _res"
assert old in s, "asyncserver.py pattern not found"
open(p, "w").write(s.replace(old, new))
print("patched asyncserver.py for python 3.14")
PYEOF
fi

echo "==> fail2ban OK"
