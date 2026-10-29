# Omarchy 1-Click builder

Builds a DigitalOcean Marketplace snapshot of [Omarchy](https://omarchy.org),
DHH's Arch Linux + Hyprland desktop OS, running natively on a droplet and
reachable from any RDP client.

## Two-stage pipeline (4.x)

Omarchy 4.x installs exclusively from its ISO; there is no script installer to
run on an existing system (that was the 3.x approach this builder originally
used). The build is therefore split:

| Stage | Where | What |
|---|---|---|
| **Base image** | KVM VM, see [base-image/](base-image/README.md) | Stock ISO autoinstall + only what a droplet needs to boot and be reachable: BIOS boot path, cloud-init (DO datasource), passwordless sudo, scrub |
| **Packer** (this directory) | `packer build omarchy-arch/template.json` | Everything else, reviewable here: remote desktop (hypr-rdp), fail2ban, autologin, cloud tuning, per-instance onboot, application tag, cleanup. Add `-var-file=omarchy-arch/gpu.vars.json` for the GPU variant |

The base image changes only when a new Omarchy version ships; day-to-day
changes to the 1-Click live in the Packer scripts.

## How this builder differs from the others in this repo

1. **Arch/Omarchy-based, not Ubuntu.** The builder's base is a custom image
   (variable `base_image_id`), not `ubuntu-24-04-x64`; the shared
   `common/scripts/*` (apt-based) are not used.
2. **SSH user is `arch`, not root.** cloud-init injects keys for the `arch`
   user (passwordless sudo). Files are uploaded to `/tmp/build-files` and
   moved into place by scripts. (Planned: the next base-image rebuild will
   create the user as `omarchy` directly; base-image/make-cidata.sh is
   already configured for it. Update ssh_username and the user references
   in this directory when that base ships.)

   Until then the two login names differ on purpose: SSH is `arch`, RDP is
   `omarchy`. hypr-rdp's `--username` is just a string it compares against and
   has no Unix account behind it, so it already uses the name the base image
   will adopt. Leave it; the rename is what makes them converge.

   Until then the two login names differ on purpose: SSH is `arch`, RDP is
   `omarchy`. hypr-rdp's `--username` is just a string it compares against and
   has no Unix account behind it, so it already uses the name the base image
   will adopt. Leave it; the rename is what makes them converge.
3. **The desktop is served over RDP at `<droplet-ip>:3389`**, by hypr-rdp,
   a native RDP server for Hyprland. RDP brings its own TLS and
   authentication, so there is no reverse proxy and no repo-standard Caddy
   here. Until the first-login setup assistant (`omarchy-droplet-setup`,
   hooked via /etc/profile.d) sets a password, the service refuses to start
   and nothing listens on 3389 at all.

   Two consequences worth knowing before changing any of it:

   - **The RDP password is held in tmpfs, and nowhere else.** RDP cannot
     authenticate against `/etc/shadow`, and this is a protocol limit rather
     than a gap in hypr-rdp: network level authentication negotiates NTLM,
     where the server must hold the password (or its MD4 "NT hash") to compute
     the challenge response, and the yescrypt hash in `/etc/shadow` (Arch's
     default, `$y$`) is one-way and cannot produce one. Some recoverable copy
     must therefore exist while the server runs. It is kept in
     `/run/hypr-rdp/password`, mode 640 root:arch, so it never touches the disk
     and cannot appear in a snapshot, image or backup. The account password is
     still only ever hashed into `/etc/shadow`, and that hash is the only thing
     about it that is persisted.

     The cost is that a reboot forgets it, which is the intended behaviour: the
     unit's `ConditionPathExists` then holds the service down, and a rebooted
     droplet serves nothing on 3389 until someone runs `omarchy-rdp-password`
     over SSH. The profile.d hook keys off the same missing file, so it prompts
     after a reboot exactly as it does on first login.
   - **The TLS keypair is generated per droplet on first boot**, not baked
     into the snapshot: one key in the image would be one key shared by every
     droplet built from it. It is self-signed, because no public CA will
     certify an IP for RDP, so clients prompt once to trust it. Unlike the
     password this one does stay on disk, because rotating it every boot would
     make clients re-prompt to trust a new fingerprint every time, training
     users to click through the warning that would otherwise catch an impostor.
4. **Desktop config is Lua** (4.x API): `o.launch_on_start(...)`,
   `o.bind("SUPER + BackSpace", ...)`, `hl.config({...})`. Note the parser
   silently ignores invalid syntax only in .conf files; Lua errors surface as
   a config-error banner in the session.

## Build

From the **repo root**, with `DIGITALOCEAN_API_TOKEN` exported and
`base_image_id` in `template.json` pointing at the current base image:

```bash
packer build omarchy-arch/template.json
```

Takes ~10-15 minutes (packages, config, fstrim, snapshot). Build droplet:
`s-2vcpu-4gb` (80 GB disk ⇒ snapshot min-disk 80 GB).

## Optional GPU image

The same `template.json` builds an image with NVIDIA drivers and Ollama added,
for droplets on GPU hardware. It is one template with a switch: `gpu.vars.json`
sets `gpu_available=true` and moves the build to a GPU droplet.

```bash
packer build -var-file=omarchy-arch/gpu.vars.json omarchy-arch/template.json
```

`optional/050-nvidia.sh` and `optional/060-ollama.sh` run in every build and
each exit immediately unless `gpu_available` is `true`, so the ordinary image
never carries a driver stack it cannot use: a normal droplet has no NVIDIA
device, and the modules would only add initramfs weight and a module that fails
to load at every boot.

The switch lives in a var file rather than a bare `-var` because the GPU build
has to change `region` and `size` as well, and those must not drift apart from
`gpu_available`. It also keeps the plain `packer build omarchy-arch/template.json`
defaulting to the cheap standard droplet, so the expensive build is never what
you get by forgetting a flag.

Two prerequisites the standard build does not have:

1. **The base image must exist in the builder's region.** GPU droplets are in
   `nyc2`; the base image is created in `nyc3`. Transfer it once, and wait for
   the action to finish before building:
   ```bash
   doctl compute image-action transfer <base_image_id> --region nyc2
   ```
2. **The build droplet is a GPU droplet**, billed by the hour for the whole
   build. Model downloads dominate that time, not the provisioning.

| Script | Purpose |
|---|---|
| `optional/050-nvidia.sh` | `nvidia-open` + `nvidia-utils` + `nvtop`, initramfs rebuild. Runs **after** `045-omarchy-update.sh` because nvidia-open ships modules prebuilt for one specific `linux` package, so it has to resolve against the kernel the image will actually boot |
| `optional/060-ollama.sh` | `ollama-cuda` (which pulls in `ollama` and `cuda`), a service drop-in, and the model downloads |

### Choosing the model set

The `ollama_models` variable holds a space-separated list. The default is the
four models benchmarked on an H100 80GB, fastest-generation first:

| Model | Generation | Prefill | Notes |
|---|---|---|---|
| `qwen3.8:27b-mtp-q8_0` | 108 tok/s | 2,327 tok/s | Fastest all-round; the sensible default |
| `qwen3.8-flash-next:125b-a6b-q4_K_M` | 64 tok/s | 627 tok/s | Strongest reasoning; spills ~36 GB to system RAM |
| `gemma4:31b-it-q8_0` | 59 tok/s | 2,279 tok/s | Fully GPU-resident |
| `qwen3.8:27b-bf16` | 48 tok/s | 4,992 tok/s | Unquantized; much the fastest at long prompts |

**That set is about 240 GB on disk, against ~7 GB for the standard image**, and
the snapshot's minimum disk size grows to match, so every droplet created from
it must be correspondingly large.

Weigh that honestly before keeping the default. Measured on a GPU droplet,
Ollama pulls at roughly 1 GB/s, so the whole 240 GB set downloads in about four
minutes on the droplet itself. Baking the models in buys a droplet that is
useful the moment it boots and needs no egress later, but it does not save a
user hours, and it costs a very large image to store and copy between regions.
If the models are not the point of the image, `ollama_models=` plus a
documented `ollama pull` is the better trade. Override the list to trim it:

```bash
# -var after -var-file wins, so the file still supplies region/size/gpu_available
packer build -var-file=omarchy-arch/gpu.vars.json \
  -var 'ollama_models=qwen3.8:27b-mtp-q8_0' omarchy-arch/template.json
packer build -var-file=omarchy-arch/gpu.vars.json \
  -var 'ollama_models=' omarchy-arch/template.json   # service only, no models
```

Models are pulled through the running server so they land in `/var/lib/ollama`
owned by the `ollama` service user. Pulling them as the build user would put
them in `~/.ollama`, where the service cannot see them.

The service listens on `127.0.0.1:11434` only, and ufw does not open that port:
an unauthenticated model server should not be reachable from outside the
droplet. Reach it remotely over an SSH tunnel rather than by rebinding it.

## What the provisioners do

| Script | Purpose |
|---|---|
| `020-remote-desktop.sh` | SDDM autologin, hypr-rdp (pinned release binary + `graphical-session` user unit + `/etc/hypr-rdp/options`), setup assistant + first-login hook, MOTD-on-ssh, per-instance onboot install |
| `025-fail2ban.sh` | fail2ban sshd jail (systemd journal backend) + rdp-limit jail (sources ufw is already rate-limiting on 3389) + a one-line patch for the fail2ban 1.1.1 / Python 3.14 startup crash (upstream; a fixed package simply overwrites it) |
| `030-optimize.sh` | Disable dead-hardware services, journal cap, **stay-awake** (4.x's idle screensaver renders at 120fps; users re-enable with `omarchy toggle idle`), `ufw limit 3389/tcp` + ufw logging (the rdp-limit jail reads those lines), scale 1 (no HiDPI; mode left at preferred so a remote client is not captured at a pinned size and upscaled), Super+BackSpace close binding |
| `035-do-agent.sh` | DigitalOcean monitoring agent (pinned release tarball; no Arch package, so no repo auto-updates; bump `DO_AGENT_VERSION` on rebuilds) |
| `036-droplet-agent.sh` | DigitalOcean droplet-agent (control panel web console); pinned release binary + upstream unit |
| `040-application-tag.sh` | `/var/lib/digitalocean/application.info` |
| `045-omarchy-update.sh` | Full system + Omarchy update, so the image ships current. Everything kernel-dependent must come after it |
| `optional/050-nvidia.sh` | **GPU builds only** (`gpu_available=true`, else exits immediately): `nvidia-open` + `nvidia-utils` + `nvtop`, initramfs rebuild. Runs **after** `045` because nvidia-open ships modules prebuilt for one specific `linux` package, so it has to resolve against the kernel the image will actually boot |
| `optional/060-ollama.sh` | **GPU builds only** (same gate): `ollama-cuda`, a loopback-only service drop-in with a 64K context, and the `ollama_models` downloads pulled through the running server |
| `900-cleanup.sh` | pacman cache purge, identity/credential scrub (SSH host keys and any hypr-rdp TLS key shredded, stray `~/.config/hypr-rdp/config.toml` removed, setup marker cleared), cloud-init instance reset, journal **deletion** (truncated journals are corrupt and break fail2ban), fstrim (measured: 6.3 GiB snapshots vs 76 GiB with dd zero-fill on DO). **Must not use `cloud-init clean`**: it wipes `/var/lib/cloud/scripts/`, deleting the baked per-instance onboot script |

### First-boot behavior (per droplet)

`files/var/lib/cloud/scripts/per-instance/001_onboot` sets a random password
for the `arch` user with pwgen so the account never keeps the build password;
it is stored only as a hash in `/etc/shadow`, never in a file or the MOTD;
users replace it with their own via the setup assistant, which the MOTD points
at. It also writes connection instructions to `/etc/motd`, and generates this
droplet's hypr-rdp TLS keypair. SSH host keys and the user's SSH keys are
provisioned fresh by cloud-init.

### Brute-force protection on the desktop password

Worth reading before changing the firewall or the jail, because the pieces only
work together.

hypr-rdp has no lockout and, verified at `RUST_LOG=debug`, logs **nothing at
all** when it rejects credentials. There is therefore no auth event for
fail2ban to count, and the Caddy-style "parse the access log" jail this
replaces cannot be ported.

What a guesser does leak is connections: RDP network level authentication
rejects a wrong password by dropping the connection, so one guess costs one new
TCP connection, and connection rate is a faithful stand-in for guess rate. The
counting therefore happens in the kernel:

1. `ufw limit 3389/tcp` rejects any source exceeding 6 new connections in 30
   seconds and logs each one as `[UFW LIMIT BLOCK] ... SRC=<ip> ... DPT=3389`.
2. The `rdp-limit` jail reads those lines off the journal's kernel transport
   and applies the usual escalating ban (1h, 2h, 4h ... 48h).

Three things follow. **ufw logging must stay on** or the jail silently never
fires, which is why `030-optimize.sh` sets it explicitly rather than relying on
the default. The jail's threshold is 10 hits in 30 minutes rather than the
sshd-style 5, because the kernel throttles that log rule to 3 lines a minute:
a client reconnecting in a burst trips ufw for a moment and is never banned,
while a real attempt keeps producing lines until the jail fires. Note that the
throttle is per-chain rather than per-source, so that arithmetic describes one
attacker, not several at once.

**Be precise about what this does and does not stop.** It is a rate limit, not
a lockout. An attacker who paces below the threshold, five connections every
thirty seconds, never produces a log line and is never banned, while still
managing on the order of ten thousand guesses a day. What actually defeats that
is the eight-character minimum and the fact that the window closes entirely on
reboot, since the password is not persisted. Customer-facing copy should say
the mechanism caps guessing and bans anything faster, and should not claim
every repeated attempt gets banned.

## What droplets gain vs 3.x

- Omarchy is a pacman package (`omarchy 4.x`): `omarchy-update -y` updates
  non-interactively.
- limine + snapper boot-snapshot integration works (the 3.x build had to skip
  the bootloader entirely); update rollback from the boot menu is available.
  This needs the per-instance fix-up in `001_onboot`: limine tags its OS entry
  with the machine-id of the machine that generated the config, so without it
  every droplet inherits the build droplet's entry, `limine-snapper-sync` never
  finds the entry it owns, and `snapper-cleanup.service` fails on its daily
  timer while snapshots silently never reach the boot menu.
- The installer opens SSH itself when built with authorized_keys (no more
  first-boot firewall lockout class of bugs; the `ensure-ssh-firewall`
  boot guard remains as insurance).

## Known limitations

- CPU-rendered graphics (no video/3D). The droplet has no audio hardware, but
  hypr-rdp forwards a PipeWire sink to the client, so desktop sound plays on
  the connecting machine.
- Marketplace `img_check` rejects non-listed distros (Arch); a policy
  conversation with the Marketplace team, not a technical gap.
- The control panel shows "monitoring not supported" and the create API
  rejects `--enable-monitoring` for custom-image lineage, even though the
  bundled do-agent collects metrics that are fully queryable via the
  monitoring API. Flipping the image's monitoring-capable flag is another
  Marketplace-team item (same basket as the img_check distro gate and its
  `/opt/digitalocean` check, which our two DO agents intentionally violate).
