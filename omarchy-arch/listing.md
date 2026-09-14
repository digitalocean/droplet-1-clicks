# Omarchy

[Omarchy](https://omarchy.org) is an opinionated Linux desktop operating system by David Heinemeier Hansson (DHH): Arch Linux plus the Hyprland tiling window manager, pre-configured with themes, keybindings, and a complete modern development toolchain. This 1-Click runs the full Omarchy desktop natively on your droplet, viewable from your browser: a persistent, accessible-from-anywhere cloud dev desktop, or the fastest way to try Omarchy without touching your laptop.

## System components

- Omarchy 4.0.3 on Arch Linux (rolling release)
- Hyprland (Wayland compositor) with the complete Omarchy desktop experience: themes, keybindings, Omarchy menu, webapps
- Development toolchain: Neovim, mise, Docker, git, and the full Omarchy app suite
- wayvnc + noVNC: browser-based remote desktop, bound to localhost and accessed over an SSH tunnel (never exposed publicly)
- ufw firewall (deny incoming, SSH allowed) with a boot-time SSH guard, plus fail2ban protecting SSH
- DigitalOcean monitoring agent: droplet graphs and alerting work out of the box
- Tuned for cloud: hardware-only services removed, compositor effects disabled for CPU rendering, 13-second boots

## System requirements

- **Minimum:** 2 vCPUs / 4 GB RAM, usable for light desktop work
- **Recommended:** 4 vCPUs / 8 GB RAM (e.g. `s-4vcpu-8gb`). The desktop is CPU-rendered, so cores directly determine how smooth it feels
- **Disk:** 80 GB or larger (image minimum)
- **No GPU required:** graphics run in software on the droplet's virtual display
- A modern browser and an SSH key for access; no VNC client needed

## Getting started

### Key bindings

Omarchy is keyboard-first. Over a remote desktop your Super key arrives as
Cmd (macOS) or Win (Windows), and the host OS intercepts several of those
combos before the browser sees them, so this image binds every essential
action on **Alt** as well. Use whichever works on your platform:

| Action | Primary | Remote-friendly |
|---|---|---|
| Terminal | `Super + Return` | `Alt + Return` |
| Omarchy menu / launcher | `Super + Space` | `Alt + Space` |
| Key bindings cheatsheet | `Super + K` | `Alt + K` |
| Close window | `Super + W` or `Super + Backspace` | `Alt + Backspace` |
| Full screen | `Super + F` | `Alt + F` |
| Workspaces 1-4 | `Super + 1..4` | `Alt + 1..4` |

Tip: put your browser in fullscreen and most Super combos work directly.

**Set your own:** add bindings to `~/.config/hypr/bindings.lua`, then run
`hyprctl reload`. A plain string runs a command; window operations use the
`hl.dsp` helpers; unbind a default before reassigning its key:

```lua
o.bind("SUPER + SHIFT + R", "SSH to my server", "alacritty -e ssh my-server")
o.bind("ALT + T", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
hl.unbind("SUPER + SPACE")  -- then rebind it below
```

Browse everything current with `omarchy menu keybindings --print`.

### Connect

From your local machine, open a tunnel to the droplet's remote desktop:

```
ssh -N -L 6080:localhost:6080 arch@your_droplet_ip
```

and open **http://localhost:6080/vnc.html** in your browser. Press `Super+K` for the keyboard shortcut cheatsheet, `Super+Return` for a terminal, and `Super+Space` for the app launcher.

To be able to lock/unlock the desktop, choose a password for the `arch` user (none is disclosed up front; a random one is set at first boot and stored only as a hash):

```
ssh arch@your_droplet_ip passwd
```

## Managing services

- **Remote desktop (noVNC):** `sudo systemctl {start|stop|restart|status} novnc`
- **Desktop session:** `sudo systemctl restart sddm` (restarts the Hyprland session)
- **VNC server:** wayvnc starts with the desktop session automatically

## Updates

- **System packages** (including security fixes): `sudo pacman -Syu`
- **Omarchy itself:** `omarchy-update -y` from any terminal or over SSH (non-interactive).
- Updates take btrfs snapshots automatically; a broken update can be rolled back from the boot menu (limine + snapper).
- Major Omarchy version jumps are best adopted by creating a new droplet from an updated image rather than upgrading in place.

## Disabled by default (and how to re-enable)

To keep the image lean and fast on a virtual machine, some stock Omarchy behavior is turned off:

- **Hardware services with no droplet hardware:** Bluetooth (`bluetooth`), printing (`cups`), network discovery (`avahi-daemon`), power profiles (`power-profiles-daemon`). These are masked; re-enable any of them with:
  ```
  sudo systemctl unmask <service> && sudo systemctl enable --now <service>
  ```
- **Screensaver and idle auto-lock:** they render continuously, wasting CPU on an unattended server. The image ships with Omarchy's "Stay Awake" toggle on; re-enable idling with:
  ```
  omarchy toggle idle
  ```
- **Compositor effects** (animations, blur, shadows, rounded corners), expensive under CPU rendering. Delete the `-- Droplet performance` block at the end of `~/.config/hypr/looknfeel.lua` and run `hyprctl reload`.
- **Display is fixed at 1280x800@60.** Change it live with `hyprctl keyword monitor Virtual-1,1920x1080@60,auto,1` (persist it in `~/.config/hypr/monitors.lua`). Higher resolutions cost CPU.
- **UKI boot images are disabled** (`ENABLE_UKI=no` drop-in): DigitalOcean droplets boot via BIOS, which requires classic kernel+initramfs limine entries. Do not re-enable UKI on a droplet; the machine will not boot.
- **Not installed at all** (not applicable to droplets): hibernation and the Plymouth boot splash. Omarchy's limine + snapper snapshot/rollback integration IS included and working.

## Notes

- Graphics are CPU-rendered (no GPU): excellent for terminals, editors, and general development; not suited to video playback or 3D.
- The droplet has no audio device.
- SSH password authentication is disabled; access uses your SSH key, and fail2ban bans repeated failed SSH attempts. The desktop password is whatever you set with `passwd` (a random unpublished one is in place until then).
