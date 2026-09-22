# Omarchy

[Omarchy](https://omarchy.org) is an opinionated Linux desktop operating system by David Heinemeier Hansson (DHH): Arch Linux plus the Hyprland tiling window manager, pre-configured with themes, keybindings, and a complete modern development toolchain. This 1-Click runs the full Omarchy desktop natively on your droplet and streams it to any remote desktop client: a persistent, accessible-from-anywhere cloud dev desktop, or the fastest way to try Omarchy without touching your laptop.

## System components

- Omarchy 4.0.4 (Latest ISO)
- Hyprland (Wayland compositor) with the complete Omarchy desktop experience: themes, keybindings, Omarchy menu, webapps, and the stock animations and visual effects left on
- Development toolchain: Neovim, mise, Docker, git, and the full Omarchy app suite
- Remote desktop at `<droplet-ip>:3389`, served by [hypr-rdp](https://github.com/MuNeNICK/hypr-rdp), a native RDP server for Hyprland: H.264 video, audio forwarded to your machine, clipboard and file transfer both ways, and TLS with a certificate generated on your droplet
- Connect with any standard RDP client. No browser plugin, no VNC, and no SSH tunnel to set up
- ufw firewall (deny incoming; SSH allowed, RDP rate-limited) with a boot-time SSH guard, plus fail2ban protecting SSH and the desktop password
- DigitalOcean agents: monitoring (metrics) and droplet-agent (the control panel's web console)
- Tuned for cloud: hardware-only services removed, 13-second boots

## System requirements

- **Minimum:** 2 vCPUs / 4 GB RAM, usable for light desktop work
- **Recommended:** 4 vCPUs / 8 GB RAM (e.g. `s-4vcpu-8gb`). The desktop is CPU-rendered, so cores directly determine how smooth it feels
- **Disk:** 80 GB or larger (image minimum)
- **No GPU required:** graphics run in software on the droplet's virtual display
- An SSH key, and an RDP client on the machine you connect from: Windows App (macOS, Windows, iOS, Android), or Remmina / FreeRDP on Linux

## Getting started

### Key bindings

Omarchy is keyboard-first. Over a remote desktop your Super key arrives as
Cmd (macOS) or Win (Windows), and the host OS intercepts several of those
combos before your client ever sees them, so this image binds every essential
action on **Alt** as well. Use whichever works on your platform:

| Action | Primary | Remote-friendly |
|---|---|---|
| Terminal | `Super + Return` | `Alt + Return` |
| Omarchy menu / launcher | `Super + Space` | `Alt + Space` |
| Key bindings cheatsheet | `Super + K` | `Alt + K` |
| Close window | `Super + W` or `Super + Backspace` | `Alt + Backspace` |
| Full screen | `Super + F` | `Alt + F` |
| Workspaces 1-4 | `Super + 1..4` | `Alt + 1..4` |

Tip: put your RDP client in fullscreen and most Super combos work directly.

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

1. Open the **Console** from your droplet's page (or `ssh arch@your_droplet_ip`).
   The setup assistant starts automatically and asks you to choose a password.
2. Point your RDP client at **your_droplet_ip:3389** and sign in as `omarchy`
   with that password. You're on the desktop.

Your client will ask you to trust the certificate the first time. That is
expected: it is self-signed and generated on your droplet at first boot, since
no public certificate authority issues certificates for a bare IP address.

The same password unlocks the desktop lock screen. Change it any time with
`omarchy-rdp-password`. Until the setup assistant runs, the remote desktop
service refuses to start, so nothing is listening on port 3389 at all.

### Your password is never written to disk

Remote desktop protocols cannot check a password against the system's hashed
password file the way SSH does: the server has to hold the password itself to
authenticate you. So instead of storing it, this image keeps it **in memory
only**. It is never written to the droplet's disk, which means it cannot end up
in a snapshot, a backup or an image. Your account password is still stored the
normal way, as a one-way hash.

The trade-off is that **rebooting switches the remote desktop off**, because the
password went with the memory that held it. Log in over SSH or the Console and
run `omarchy-rdp-password` to turn it back on. That is also how you change it.

**Prefer no public endpoint?** Add this to `/etc/hypr-rdp/options`:

```
BIND="127.0.0.1:3389"
```

then take it off the internet and tunnel instead:

```
systemctl --user restart hypr-rdp
sudo ufw delete limit 3389/tcp
ssh -N -L 3389:localhost:3389 arch@your_droplet_ip
```

then point your RDP client at `localhost:3389`.

## Managing services

- **Remote desktop:** `systemctl --user {start|stop|restart|status} hypr-rdp`, as the `arch` user. It belongs to the desktop session, so it is a user service, not a system one
- **Tuning it** (frame rate, bitrate, quality): edit `/etc/hypr-rdp/options`, which documents the available settings, then restart the service
- **Desktop session:** `sudo systemctl restart sddm` (restarts Hyprland, and the remote desktop with it)
- **fail2ban (SSH + desktop):** `sudo fail2ban-client status sshd` and `sudo fail2ban-client status rdp-limit`. Unban an IP with `sudo fail2ban-client set rdp-limit unbanip <ip>`

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
- **HiDPI scaling**, expensive under CPU rendering: outputs run at scale 1. Each output still uses its preferred mode, so a remote-desktop client gets its own resolution rather than a pinned one. Raise the scale in `~/.config/hypr/monitors.lua`; higher resolutions cost CPU.
- **UKI boot images are disabled** (`ENABLE_UKI=no` drop-in): DigitalOcean droplets boot via BIOS, which requires classic kernel+initramfs limine entries. Do not re-enable UKI on a droplet; the machine will not boot.
- **Not installed at all** (not applicable to droplets): hibernation and the Plymouth boot splash. Omarchy's limine + snapper snapshot/rollback integration IS included and working.

## Notes

- Graphics are CPU-rendered (no GPU): excellent for terminals, editors, and general development; not suited to video playback or 3D.
- The droplet has no audio hardware, but desktop sound is forwarded over RDP and plays on the machine you connect from.
- SSH password authentication is disabled; access uses your SSH key, and fail2ban bans repeated failed SSH attempts.
- The desktop password is whatever the setup assistant set, and a random unpublished one guards the account until then. It is held in memory only and never written to the droplet's disk, so a reboot switches the remote desktop off until you turn it back on over SSH.
- Port 3389 is rate-limited: ufw rejects more than six connection attempts from one address every thirty seconds, which caps password guessing at roughly ten tries a minute, and fail2ban bans addresses that exceed that, for longer each time they come back. Choose a strong password regardless: a rate limit slows guessing down, it does not make a weak password safe.
