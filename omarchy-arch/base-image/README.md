# Omarchy 4.x base image build

The Packer builder in the parent directory starts from a **base custom image**:
a stock Omarchy 4.x ISO autoinstall with only the changes a droplet needs
before Packer can reach it. Everything user-visible (remote desktop, fail2ban,
tuning, onboot) lives in the Packer provisioners, not here.

## Why a VM pipeline at all

Omarchy 4.x installs exclusively from its ISO (there is no script installer,
unlike 3.x). Droplets cannot boot ISOs, so the base image is produced by
running the ISO's official unattended install ("cidata autoinstall") in a KVM
VM and uploading the resulting disk as a DO custom image.

## What the base image contains beyond stock Omarchy

1. **BIOS boot path.** DO custom-image droplets boot with BIOS firmware; the
   ISO installs UEFI-only (limine + UKI). The base build adds a BIOS boot
   partition, installs limine's BIOS stage, disables UKI generation
   (`ENABLE_UKI=no` drop-in) so classic kernel+initramfs entries exist, sets a
   3s boot timeout, points `default_entry` at the linux entry, and installs a
   pacman hook that re-asserts those settings whenever a kernel or limine
   update regenerates `limine.conf`.
2. **cloud-init** with the DigitalOcean datasource (SSH key injection,
   per-instance scripts). cloud-init 24.x unit names.
3. **Passwordless sudo** for wheel (the ISO-created user has password sudo;
   Packer provisioners and the onboot script rely on NOPASSWD).
4. **Scrub** to fresh-image semantics (no keys, histories, host keys,
   machine-id, cloud-init state; journals deleted, not truncated).

## Build procedure (KVM host, e.g. any droplet with /dev/kvm)

```bash
# 1. Fetch and verify the ISO
curl -LO https://iso.omarchy.org/omarchy-<version>.iso
curl -LO https://iso.omarchy.org/omarchy-<version>.iso.sha256
sha256sum -c omarchy-<version>.iso.sha256

# 2. Autoinstall seed (build password is rotated at first boot by onboot)
./make-cidata.sh '<build-password>' ~/.ssh/id_ed25519.pub 60

# 3. Unattended install into a fresh VM (secure boot OFF: the ISO is unsigned)
virt-install --name omarchy-base --memory 6144 --vcpus 4 --cpu host \
  --disk path=/var/lib/libvirt/images/omarchy-base.qcow2,size=60,format=qcow2,bus=virtio,discard=unmap \
  --disk path=/var/lib/libvirt/images/omarchy-<version>.iso,device=cdrom,readonly=on \
  --disk path=/var/lib/libvirt/images/cidata.iso,device=cdrom,readonly=on \
  --osinfo archlinux --import \
  --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd,hd,cdrom \
  --network network=default --graphics vnc,listen=127.0.0.1 --video virtio --noautoconsole
# ISOs must live where the libvirt-qemu user can read them (not /root)

# 4. When SSH answers on the VM (~6 min): bootstrap NOPASSWD sudo, run minimal-base.sh
ssh arch@<vm-ip> "echo '<build-password>' | sudo -S bash -c \
  'echo \"%wheel ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/99-wheel-nopasswd'"
scp minimal-base.sh arch@<vm-ip>:/tmp/ && ssh arch@<vm-ip> 'bash /tmp/minimal-base.sh'

# 5. Verify BIOS boot before uploading (this is what DO uses)
virsh shutdown omarchy-base   # wait for shut off
qemu-img create -f qcow2 -b /var/lib/libvirt/images/omarchy-base.qcow2 -F qcow2 /tmp/biostest.qcow2
virt-install --name biostest --memory 4096 --vcpus 2 \
  --disk path=/tmp/biostest.qcow2,bus=virtio --osinfo archlinux --import \
  --network network=default --graphics vnc --noautoconsole
# SeaBIOS (default firmware) must reach SSH unattended; then destroy biostest.
# The overlay dirties the base's host keys etc.: re-run only the scrub block
# of minimal-base.sh inside the base VM, or scrub offline with virt-customize.

# 6. Compress and upload
qemu-img convert -O qcow2 -c /var/lib/libvirt/images/omarchy-base.qcow2 omarchy-base-<version>.qcow2
python3 -m http.server 8123 &   # or upload to Spaces
doctl compute image create omarchy-<version>-base --region nyc3 \
  --image-url "http://<host-ip>:8123/omarchy-base-<version>.qcow2" \
  --image-distribution "Arch Linux"

# 7. Point base_image_id in ../template.json at the new image ID
```

## Known upstream issues the pipeline works around

- **Secure boot**: the ISO is unsigned; UEFI VMs need secure boot disabled
  (`pre-enrolled-keys=0` on Proxmox, non-`.ms` OVMF firmware on libvirt).
- **fail2ban vs Python 3.14**: crash at startup; patched in the Packer stage
  (`025-fail2ban.sh`) until the Arch package catches up.
- **Journald**: truncated journal files are corrupt and break fail2ban's
  systemd backend; scrubs must delete them instead.
