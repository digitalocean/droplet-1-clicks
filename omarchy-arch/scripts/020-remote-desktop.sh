#!/bin/bash
#
# Remote desktop for Omarchy 4.x: SDDM autologin into the omarchy session plus
# hypr-rdp, a native RDP server for Hyprland, listening on the droplet's public
# IP. RDP carries its own TLS and authentication, so unlike the previous
# noVNC/wayvnc stack there is no reverse proxy in front of it and no tunnel to
# set up: any RDP client connects straight to <droplet-ip>:3389.
set -euo pipefail

HYPR_RDP_VERSION="0.1.6"
# Pinned by digest as well as version: this binary terminates TLS on a public
# port, so a silently replaced release asset is worth more here than the
# convenience of skipping the check. Recompute with sha256sum when bumping.
HYPR_RDP_SHA256="f6f52a4683c6a6aae7543a13dbe445e7494e4e77a0e2e794a644740827ed304a"

echo "==> SDDM autologin (stock 4.x waits at the greeter; a droplet has no keyboard)"
sudo tee /etc/sddm.conf.d/20-autologin.conf >/dev/null <<'EOF'
[Autologin]
User=arch
Session=omarchy
EOF

echo "==> Installing hypr-rdp ${HYPR_RDP_VERSION} runtime dependencies"
# The upstream release ships a bare binary, so the shared libraries the AUR
# package would have pulled in have to be named here. pipewire is listed even
# though Omarchy already ships it: it is what carries audio to the client, and
# naming it means a future base image that drops it fails the build instead of
# silently shipping a desktop with no sound. pwgen and openssl are for the
# per-instance onboot script (random account password, per-droplet cert).
sudo pacman -S --noconfirm --needed \
  fuse3 libpulse libva libxkbcommon mesa pipewire pipewire-pulse \
  pwgen openssl 2>&1 | tail -1

echo "==> Installing hypr-rdp ${HYPR_RDP_VERSION}"
# Pinned release binary rather than the AUR package: the AUR builds this Rust
# project from source (minutes of build-droplet time) and always tracks the
# newest version, which would make image contents depend on build date. Bump
# HYPR_RDP_VERSION to move. The tarball is flat, hence the temporary directory.
curl -fsSL "https://github.com/MuNeNICK/hypr-rdp/releases/download/v${HYPR_RDP_VERSION}/hypr-rdp-v${HYPR_RDP_VERSION}-x86_64-linux.tar.gz" \
  -o /tmp/hypr-rdp.tgz
echo "${HYPR_RDP_SHA256}  /tmp/hypr-rdp.tgz" | sha256sum -c -
rm -rf /tmp/hypr-rdp-unpack && mkdir -p /tmp/hypr-rdp-unpack
tar xzf /tmp/hypr-rdp.tgz -C /tmp/hypr-rdp-unpack
sudo install -m 755 /tmp/hypr-rdp-unpack/hypr-rdp /usr/local/bin/hypr-rdp
rm -rf /tmp/hypr-rdp.tgz /tmp/hypr-rdp-unpack
/usr/local/bin/hypr-rdp --version

echo "==> hypr-rdp config directory (the certificate is written on first boot)"
# Root-owned, group arch. hypr-rdp runs inside the arch user's graphical session
# and only ever reads what is in here, so it does not need write access to its
# own TLS key or to the options file its launcher sources.
sudo install -d -m 750 -o root -g arch /etc/hypr-rdp
sudo install -m 644 -o root -g arch /tmp/build-files/etc/hypr-rdp/options /etc/hypr-rdp/options

echo "==> Installing the hypr-rdp user service"
# A systemd *user* service, not a Hyprland autostart entry: Omarchy 4.x starts
# the session through uwsm, so the user manager has WAYLAND_DISPLAY and
# HYPRLAND_INSTANCE_SIGNATURE in its environment and can bind the server's
# lifetime to graphical-session.target. Autostart lines get neither ordering
# nor a restart policy.
sudo install -m 644 /tmp/build-files/etc/systemd/user/hypr-rdp.service /etc/systemd/user/
# --global enables it for every user without needing a live user manager during
# the build (packer's ssh session has no graphical session of its own).
sudo systemctl --global enable hypr-rdp.service

echo "==> Installing systemd units"
sudo cp /tmp/build-files/etc/systemd/system/ensure-ssh-firewall.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ensure-ssh-firewall.service

echo "==> Enabling MOTD on login"
sudo cp /tmp/build-files/etc/ssh/sshd_config.d/10-omarchy-motd.conf /etc/ssh/sshd_config.d/

echo "==> Installing the setup assistant + first-login hook"
sudo install -m 755 /tmp/build-files/usr/local/bin/omarchy-droplet-setup /usr/local/bin/
sudo install -m 755 /tmp/build-files/usr/local/bin/omarchy-rdp-server /usr/local/bin/
sudo install -m 755 /tmp/build-files/usr/local/bin/omarchy-rdp-password /usr/local/bin/
sudo install -m 644 /tmp/build-files/etc/profile.d/omarchy-first-setup.sh /etc/profile.d/

echo "==> Installing per-instance onboot script (unique password + cert + MOTD per droplet)"
sudo mkdir -p /var/lib/cloud/scripts/per-instance
sudo cp /tmp/build-files/var/lib/cloud/scripts/per-instance/001_onboot /var/lib/cloud/scripts/per-instance/001_onboot
sudo chown root:root /var/lib/cloud/scripts/per-instance/001_onboot
sudo chmod 755 /var/lib/cloud/scripts/per-instance/001_onboot

echo "==> Remote desktop OK"
