# Omarchy

[Omarchy](https://omarchy.org) is an opinionated Linux desktop operating system by David Heinemeier Hansson (DHH) — Arch Linux plus the Hyprland tiling window manager, pre-configured with themes, keybindings, and a complete modern development toolchain. This 1-Click runs the full Omarchy desktop natively on your droplet, viewable from your browser: a persistent, accessible-from-anywhere cloud dev desktop, or the fastest way to try Omarchy without touching your laptop.

## System components

- Omarchy 3.8.5 on Arch Linux (rolling release)
- Hyprland (Wayland compositor) with the complete Omarchy desktop experience — themes, keybindings, Omarchy menu, webapps
- Development toolchain: Neovim, mise, Docker, git, and the full Omarchy app suite
- wayvnc + noVNC: browser-based remote desktop, bound to localhost and accessed over an SSH tunnel (never exposed publicly)
- ufw firewall (deny incoming, SSH allowed) with a boot-time SSH guard, plus fail2ban protecting SSH
- Tuned for cloud: hardware-only services removed, compositor effects disabled for CPU rendering, 13-second boots

## Getting started

From your local machine, open a tunnel to the droplet's remote desktop:

```
ssh -N -L 6080:localhost:6080 arch@your_droplet_ip
```

and open **http://localhost:6080/vnc.html** in your browser. Press `Super+K` for the keyboard shortcut cheatsheet, `Super+Return` for a terminal, and `Super+Space` for the app launcher.

To be able to lock/unlock the desktop, choose a password for the `arch` user (none is disclosed up front — a random one is set at first boot and stored only as a hash):

```
ssh arch@your_droplet_ip passwd
```

## Managing services

- **Remote desktop (noVNC):** `sudo systemctl {start|stop|restart|status} novnc`
- **Desktop session:** `sudo systemctl restart sddm` (restarts the Hyprland session)
- **VNC server:** wayvnc starts with the desktop session automatically

## Updates

- **System packages** (including security fixes): `sudo pacman -Syu`
- **Omarchy itself:** run `omarchy-update` from a terminal *inside the desktop* (or via `bash -lic omarchy-update` over SSH). Confirm prompts interactively.
- Major Omarchy version upgrades (e.g. 4.x) are best adopted by creating a new droplet from an updated image rather than upgrading in place.

## Notes

- Graphics are CPU-rendered (no GPU): excellent for terminals, editors, and general development; not suited to video playback or 3D.
- The droplet has no audio device.
- SSH password authentication is disabled; access uses your SSH key, and fail2ban bans repeated failed SSH attempts. The desktop password is whatever you set with `passwd` (a random unpublished one is in place until then).
