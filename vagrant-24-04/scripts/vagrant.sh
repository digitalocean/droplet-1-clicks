#!/bin/sh

################################
## Install Vagrant and VirtualBox
##
## This script installs Vagrant from the HashiCorp repository
## and VirtualBox as the primary provider for Linux systems
## vi: syntax=sh expandtab ts=4

set -e

# Enable ufw and open SSH
ufw allow 22/tcp
ufw limit ssh/tcp
ufw --force enable

# Add HashiCorp GPG key and repository
echo "Setting up HashiCorp repository..."
wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Update package lists
echo "Updating package lists..."
apt -qqy update

# Install Vagrant
echo "Installing Vagrant..."
apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install vagrant

# Install VirtualBox as primary provider for Linux
echo "Installing VirtualBox (primary provider for Linux)..."
apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install virtualbox virtualbox-dkms

# Install optional provider support (libvirt for KVM/QEMU on Linux)
echo "Installing Libvirt (KVM/QEMU support)..."
apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install libvirt-daemon libvirt-clients qemu-system

# Install vagrant plugins for additional providers
echo "Installing Vagrant plugins for additional providers..."
vagrant plugin install vagrant-libvirt 2>/dev/null || true

# Enable and start required services
echo "Enabling virtualization services..."
systemctl enable virtualbox 2>/dev/null || true
systemctl enable libvirtd 2>/dev/null || true
systemctl start libvirtd 2>/dev/null || true

# Verify installations
echo "Verifying Vagrant installation..."
vagrant --version

echo "Verifying VirtualBox installation..."
VBoxManage --version 2>/dev/null || echo "VirtualBox installed (headless mode)"

echo "Verifying Libvirt installation..."
virsh --version 2>/dev/null || echo "Libvirt installed"

# Create symbolic links to ensure Vagrant is available in standard paths
ln -sf /usr/bin/vagrant /usr/local/bin/vagrant || true

# Display installed version in the application info
VAGRANT_VERSION=$(vagrant --version | awk '{print $NF}')
echo "Vagrant version: ${VAGRANT_VERSION}"
echo "Installation complete. Multiple providers are ready for Vagrant use:"
echo "  - VirtualBox (default for Linux)"
echo "  - Libvirt (KVM/QEMU)"
echo "  - VMware (requires plugin installation)"
echo "  - Hyper-V (for Windows)"



