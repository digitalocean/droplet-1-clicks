#!/bin/bash
#
# Cloud tuning for Omarchy 4.x: no dead-hardware services, no CPU-burning
# desktop effects or idle screensaver, journal cap. Config edits use the 4.x
# lua API (hl.config / o.bind / o.launch_on_start).
set -euo pipefail

echo "==> Disabling dead-hardware services"
sudo systemctl disable --now \
  bluetooth.service cups.service cups.socket cups.path \
  avahi-daemon.service avahi-daemon.socket \
  power-profiles-daemon.service 2>/dev/null || true
sudo systemctl mask \
  bluetooth.service cups.service avahi-daemon.service \
  power-profiles-daemon.service 2>/dev/null || true

echo "==> Firewall: allow http/https (ACME challenge + the public desktop page)"
sudo ufw allow http >/dev/null
sudo ufw allow https >/dev/null

echo "==> Unattended updates: silence sudo -v (omarchy-update validates credentials under a pty)"
# The ISO installer leaves a password-required rule (04_arch); with default
# verifypw=all, ANY passworded rule makes `sudo -v` prompt, hanging
# omarchy-update -y. verifypw=any succeeds via our NOPASSWD:ALL rule while
# leaving per-command authorization untouched.
sudo rm -f /etc/sudoers.d/04_arch
printf "%%%%wheel ALL=(ALL) NOPASSWD: ALL\nDefaults verifypw = any\n" | sudo tee /etc/sudoers.d/99-wheel-nopasswd >/dev/null
sudo chmod 440 /etc/sudoers.d/99-wheel-nopasswd
sudo visudo -c >/dev/null

echo "==> OMARCHY_PATH for all session types (omarchy-update needs it; only login shells set it)"
grep -q "^OMARCHY_PATH=" /etc/environment 2>/dev/null ||
  echo "OMARCHY_PATH=/usr/share/omarchy" | sudo tee -a /etc/environment >/dev/null

echo "==> Honor ACPI power-off (Omarchy ignores the power key; droplets and Packer shut down via ACPI)"
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/zz-droplet-power.conf >/dev/null <<'EOF'
[Login]
HandlePowerKey=poweroff
EOF
# logind only reads its config at start; without this, the packer build's own
# graceful shutdown (an ACPI power-button press) times out
sudo systemctl restart systemd-logind

echo "==> Capping journal size"
sudo mkdir -p /etc/systemd/journald.conf.d
printf "[Journal]\nSystemMaxUse=64M\n" | sudo tee /etc/systemd/journald.conf.d/size.conf >/dev/null

echo "==> Stay awake: no screensaver/idle-lock (the 4.x screensaver renders at 120fps)"
# Upstream-supported toggle; users re-enable idling with: omarchy toggle idle
mkdir -p ~/.local/state/omarchy/indicators
touch ~/.local/state/omarchy/indicators/stay-awake

echo "==> Display: 1280x800@60, no HiDPI (CPU rendering)"
sed -i 's/local omarchy_gdk_scale = 2/local omarchy_gdk_scale = 1/' ~/.config/hypr/monitors.lua
sed -i 's/mode = "preferred", position = "auto", scale = omarchy_monitor_scale/mode = "1280x800@60", position = "auto", scale = 1/' ~/.config/hypr/monitors.lua

echo "==> Compositor: no animations/blur/shadows/rounding"
cat >> ~/.config/hypr/looknfeel.lua <<'EOF'

-- Droplet performance (software rendering)
hl.config({
  animations = { enabled = false },
  decoration = {
    rounding = 0,
    blur = { enabled = false },
    shadow = { enabled = false },
  },
})
EOF

echo "==> ALT mirrors for essential bindings (host OSes intercept many Super/Cmd combos over noVNC)"
cat >> ~/.config/hypr/bindings.lua <<'EOF'

-- Close window without Super+W: Cmd+W closes the browser tab when using noVNC on macOS
-- (plain-string third args are exec'd as commands; raw dispatchers need hl.dsp.*)
o.bind("SUPER + BackSpace", "Close window", hl.dsp.window.close())

-- ALT mirrors of the essentials: Super arrives as Cmd/Win from remote viewers,
-- and host OSes intercept many of those combos before the browser sees them.
-- Alt passes through cleanly on macOS and mostly on Windows.
o.bind("ALT + RETURN", "Terminal", { omarchy = "terminal" })
o.bind("ALT + SPACE", "Omarchy menu", "omarchy-menu")
o.bind("ALT + K", "Keybindings cheatsheet", "omarchy-menu-keybindings")
o.bind("ALT + BackSpace", "Close window", hl.dsp.window.close())
o.bind("ALT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("ALT + 1", "Workspace 1", hl.dsp.focus({ workspace = "1" }))
o.bind("ALT + 2", "Workspace 2", hl.dsp.focus({ workspace = "2" }))
o.bind("ALT + 3", "Workspace 3", hl.dsp.focus({ workspace = "3" }))
o.bind("ALT + 4", "Workspace 4", hl.dsp.focus({ workspace = "4" }))
EOF

echo "==> Optimize OK"
