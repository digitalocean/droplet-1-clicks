#!/bin/bash
#
# OPTIONAL: NVIDIA drivers, for images destined for GPU droplets.
#
# Every build runs this, so it decides for itself from the gpu_available build
# variable (see gpu.vars.json). The standard image must never carry a ~1 GB
# driver stack it can do nothing with: a normal droplet has no NVIDIA device,
# and installing the modules there only adds initramfs weight and a kernel
# module that fails to load at every boot.
#
# Must run AFTER 045-omarchy-update.sh. nvidia-open ships modules prebuilt
# against the exact `linux` package it was released for, so it has to be
# resolved against the kernel the image will actually boot. Installing it
# before the update leaves modules built for the outgoing kernel, and the GPU
# comes up with no driver on first boot.
set -euo pipefail

if [[ ${gpu_available:-false} != "true" ]]; then
  echo "==> Skipping NVIDIA drivers (gpu_available=${gpu_available:-false})"
  exit 0
fi

echo "==> Installing NVIDIA drivers (kernel: $(pacman -Q linux | awk '{print $2}'))"
# nvidia-open, not nvidia: NVIDIA's open kernel modules are the supported path
# for Turing and newer, which covers every NVIDIA GPU DigitalOcean offers
# (H100, L40S, RTX 6000 Ada). They are also the only variant NVIDIA still
# builds for the newest datacenter parts.
#
# No nouveau blacklist is written here on purpose: nvidia-utils already ships
# one in /usr/lib/modprobe.d/nvidia-utils.conf, and a second copy in /etc would
# be a duplicate that outlives the package if the driver is ever removed.
sudo pacman -S --noconfirm --needed nvidia-open nvidia-utils 2>&1 | tail -1

echo "==> Installing GPU inspection tools"
sudo pacman -S --noconfirm --needed nvtop 2>&1 | tail -1

echo "==> Rebuilding initramfs"
# The driver drops a mkinitcpio hook, but that fires from a pacman hook whose
# ordering we would rather not depend on inside a build. Doing it explicitly
# also surfaces a broken initramfs here, where the build fails loudly, instead
# of at first boot where it is an unreachable droplet.
sudo mkinitcpio -P 2>&1 | grep -iE "error|warning|Image generation successful" | tail -5

echo "==> Verifying"
# The build droplet usually IS a GPU droplet (it needs the disk for models),
# but the driver installs fine without one, so a missing GPU is reported rather
# than treated as a failure. The module cannot be loaded yet regardless: it was
# built for a kernel this machine has not booted into.
if command -v nvidia-smi >/dev/null; then
  echo "    nvidia-smi installed: $(pacman -Q nvidia-utils | awk '{print $2}')"
  if nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null; then
    :
  else
    echo "    no GPU visible at build time (expected until the droplet reboots)"
  fi
else
  echo "Error: nvidia-smi missing after install" >&2
  exit 1
fi

echo "==> NVIDIA OK"
