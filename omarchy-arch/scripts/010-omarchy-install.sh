#!/bin/bash
#
# Install Omarchy on the Arch cloud image. Runs as the `arch` user
# (passwordless sudo). See readme.md for the rationale behind each patch.
set -euo pipefail

echo "==> Configuring pacman mirrors (Omarchy stable mirror first, stock Arch as fallback)"
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
{
  echo 'Server = https://stable-mirror.omarchy.org/$repo/os/$arch'
  cat /etc/pacman.d/mirrorlist.orig
} | sudo tee /etc/pacman.d/mirrorlist >/dev/null

sudo pacman -Syu --noconfirm --needed git

echo "==> Cloning Omarchy (${omarchy_ref})"
rm -rf ~/.local/share/omarchy
git clone --branch "${omarchy_ref}" https://github.com/basecamp/omarchy.git ~/.local/share/omarchy 2>/dev/null ||
  git clone --branch master https://github.com/basecamp/omarchy.git ~/.local/share/omarchy
cd ~/.local/share/omarchy
git log --oneline -1

echo "==> Applying droplet patches"
echo 'echo "Guards: OK (bypassed for DigitalOcean droplet)"' > install/preflight/guard.sh

# Base packages install the `limine` package, defeating this script's own
# `command -v limine` guard; it must never touch the bootloader.
echo 'echo "Skipping limine-snapper (droplet keeps cloud image bootloader)"' > install/login/limine-snapper.sh

echo 'echo "Skipping hibernation setup (droplet)"' > install/login/hibernation.sh
echo 'echo "Skipping plymouth theme (droplet)"' > install/login/plymouth.sh

# Without this, the first desktop boot enables ufw deny-all -> SSH lockout.
# Path is install/first-run/firewall.sh on 3.8.x, install/config/firewall.sh on 4.x.
patched_fw=false
for fw in install/first-run/firewall.sh install/config/firewall.sh; do
  if [[ -f $fw ]]; then
    sed -i '/ufw default allow outgoing/a sudo ufw allow 22/tcp' "$fw"
    grep -q "allow 22/tcp" "$fw" || { echo "ERROR: firewall patch failed on $fw"; exit 1; }
    patched_fw=true
  fi
done
$patched_fw || { echo "ERROR: no firewall.sh found to patch"; exit 1; }

# The finishing screen's interactive reboot prompt would hang an unattended build
echo 'echo "Install finished (unattended build)"' > install/post-install/finished.sh

echo "==> Launching Omarchy installer detached from SSH"
# The install switches networkd -> NetworkManager mid-run, dropping Packer's
# SSH session, so it runs detached and 015-wait-install.sh polls the markers.
# Markers/logs must be in /tmp (this runs unprivileged; /var/log is root-only).
# `script` provides the TTY the installer requires (`stty size </dev/tty`).
export OMARCHY_ONLINE_INSTALL=true
rm -f /tmp/omarchy-build.done /tmp/omarchy-build.failed
cat > /tmp/run-omarchy-install.sh <<'EOF'
#!/bin/bash
export OMARCHY_ONLINE_INSTALL=true
if script -qec "bash $HOME/.local/share/omarchy/install.sh" /tmp/omarchy-install-console.log; then
  touch /tmp/omarchy-build.done
else
  touch /tmp/omarchy-build.failed
fi
EOF
chmod +x /tmp/run-omarchy-install.sh
setsid nohup /tmp/run-omarchy-install.sh >/tmp/omarchy-build.log 2>&1 </dev/null &
disown
sleep 3
exit 0
