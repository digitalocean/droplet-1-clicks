#!/bin/bash
#
# Cloud tuning for Omarchy 4.x: no dead-hardware services, no idle screensaver,
# journal cap, firewall. Config edits use the 4.x lua API (hl.config / o.bind /
# o.launch_on_start).
set -euo pipefail

echo "==> Disabling dead-hardware services"
sudo systemctl disable --now \
  bluetooth.service cups.service cups.socket cups.path \
  avahi-daemon.service avahi-daemon.socket \
  power-profiles-daemon.service 2>/dev/null || true
sudo systemctl mask \
  bluetooth.service cups.service avahi-daemon.service \
  power-profiles-daemon.service 2>/dev/null || true

echo "==> Firewall: rate-limited RDP (the public desktop)"
# `limit`, not `allow`: ufw rejects a source that opens more than 6 connections
# in 30 seconds, which is the only throttle a password guesser meets, since
# hypr-rdp has no lockout of its own and logs nothing when it rejects
# credentials. Each drop is logged, and fail2ban's rdp-limit jail turns a
# source that keeps at it into an escalating ban, so logging is load-bearing
# here rather than cosmetic: with it off the jail silently never fires.
sudo ufw limit 3389/tcp >/dev/null
sudo ufw logging low >/dev/null

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

echo "==> Display: no HiDPI (CPU rendering)"
# Match whatever upstream ships: this default has changed between Omarchy
# releases (4.0.3 used 4, 4.0.4 uses 2), and a literal pattern silently leaves
# the value untouched on any release that disagrees with it.
sed -i 's/^local omarchy_gdk_scale = .*/local omarchy_gdk_scale = 1/' ~/.config/hypr/monitors.lua
# Drop the HiDPI scale but leave the mode alone. Pinning a mode here set it on
# every output, including the headless one a remote-desktop server creates for
# the client: the session was captured at the pinned size and then upscaled to
# the client's real resolution, so anything above it arrived soft.
#
# Match only the assignment, not the whole hl.monitor line: the surrounding
# arguments are upstream's to reorder, and a longer literal would quietly match
# nothing the first time they do.
sed -i 's/scale = omarchy_monitor_scale/scale = 1/' ~/.config/hypr/monitors.lua
# Assert both edits landed. A silent no-op here ships an image whose listing
# advertises scale 1 while the desktop runs at whatever upstream defaults to,
# and nothing downstream would notice.
if ! grep -q '^local omarchy_gdk_scale = 1$' ~/.config/hypr/monitors.lua; then
  echo "Error: could not set omarchy_gdk_scale in monitors.lua" >&2
  exit 1
fi
if grep -q 'scale = omarchy_monitor_scale' ~/.config/hypr/monitors.lua; then
  echo "Error: monitors.lua still scales outputs by omarchy_monitor_scale" >&2
  exit 1
fi

# Compositor effects (animations, blur, shadows, rounding) are left at Omarchy's
# defaults. They used to be disabled here, from when the desktop was delivered
# as a stream of JPEG tiles over VNC and every repainted pixel was re-encoded at
# full cost. RDP sends H.264, where a short animation is cheap and a static
# desktop costs almost nothing, so the trade no longer pays for itself: the
# image looked unlike Omarchy and saved little. Users who want the old behavior
# can turn effects off in ~/.config/hypr/looknfeel.lua.

echo "==> ALT mirrors for essential bindings (host OSes intercept many Super/Cmd combos)"
cat >> ~/.config/hypr/bindings.lua <<'EOF'

-- Close window without Super+W: Cmd+W is intercepted by some remote desktop clients
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
