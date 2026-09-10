# Omarchy

[Omarchy](https://omarchy.org) is an opinionated Linux desktop operating system by David Heinemeier Hansson (DHH) — Arch Linux plus the Hyprland tiling window manager, pre-configured with themes, keybindings, and a complete modern development toolchain. This 1-Click runs the full Omarchy desktop natively on your droplet, viewable from your browser: a persistent, accessible-from-anywhere cloud dev desktop, or the fastest way to try Omarchy without touching your laptop.

## System components

- Omarchy 3.8.5 on Arch Linux (rolling release)
- Hyprland (Wayland compositor) with the complete Omarchy desktop experience — themes, keybindings, Omarchy menu, webapps
- Development toolchain: Neovim, mise, Docker, git, and the full Omarchy app suite
- wayvnc + noVNC: browser-based remote desktop, bound to localhost and accessed over an SSH tunnel (never exposed publicly)
- ufw firewall (deny incoming, SSH allowed) with a boot-time SSH guard
- Tuned for cloud: hardware-only services removed, compositor effects disabled for CPU rendering, 13-second boots

## Getting started

After creating the droplet, log in once to read your unique desktop password from the welcome message:

```
ssh arch@your_droplet_ip
```

Then, from your local machine:

```
ssh -N -L 6080:localhost:6080 arch@your_droplet_ip
```

and open **http://localhost:6080/vnc.html** in your browser. Unlock the desktop with the password shown in the MOTD. Press `Super+K` for the keyboard shortcut cheatsheet, `Super+Return` for a terminal, and `Super+Space` for the app launcher.

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
- SSH password authentication is disabled; access uses your SSH key. The desktop password is unique per droplet and shown in the MOTD.
