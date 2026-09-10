#!/bin/bash
#
# Cloud tuning: no dead-hardware services, no CPU-burning desktop effects.
set -euo pipefail

echo "==> Disabling dead-hardware services"
sudo systemctl disable --now \
  bluetooth.service iwd.service \
  cups.service cups.socket cups.path cups-browsed.service \
  avahi-daemon.service avahi-daemon.socket \
  power-profiles-daemon.service systemd-homed.service 2>/dev/null || true
sudo systemctl mask \
  bluetooth.service iwd.service cups.service \
  avahi-daemon.service power-profiles-daemon.service 2>/dev/null || true

echo "==> Not blocking boot on NTP sync (timesyncd still syncs in background)"
sudo systemctl disable systemd-time-wait-sync.service || true

echo "==> Capping journal size"
sudo mkdir -p /etc/systemd/journald.conf.d
printf "[Journal]\nSystemMaxUse=64M\n" | sudo tee /etc/systemd/journald.conf.d/size.conf >/dev/null

echo "==> No screensaver/auto-lock (they render continuously; box is tunnel-secured)"
sed -i '/^listener {/,/^}/d' ~/.config/hypr/hypridle.conf

echo "==> Display: 1280x800@60, no HiDPI scaling"
cat > ~/.config/hypr/monitors.conf <<'EOF'
# Virtual display on a DigitalOcean droplet
env = GDK_SCALE,1
monitor=,1280x800@60,auto,1
EOF

echo "==> Extra close-window binding (browsers on macOS steal Cmd+W over noVNC)"
cat >> ~/.config/hypr/bindings.conf <<'EOF'

# Close window without Super+W — Cmd+W closes the browser tab when using noVNC on macOS
bind = SUPER, BackSpace, killactive
EOF

echo "==> Compositor: no animations/blur/shadows/rounding (CPU rendering)"
# Must be namespaced keys — Hyprland silently ignores one-line `cat { k = v }` blocks
cat >> ~/.config/hypr/hyprland.conf <<'EOF'

# --- Droplet performance (software rendering) ---
animations:enabled = false
decoration:blur:enabled = false
decoration:shadow:enabled = false
decoration:rounding = 0
misc:disable_hyprland_logo = true
EOF

echo "==> Optimize OK"
