# Vagrant 1-Click Droplet Builder

This directory contains the Packer builder configuration for the Vagrant 1-Click Application on DigitalOcean.

## Overview

This builder creates a DigitalOcean Droplet snapshot with Vagrant pre-installed and configured, ready to use immediately after deployment.

## What is Vagrant?

Vagrant is a tool for building and managing virtual machine environments in a single workflow. It uses infrastructure as code to configure, provision, and manage virtual machines across multiple platforms.

For more information, visit: https://developer.hashicorp.com/vagrant

## Included Components

- **Vagrant** - Latest stable version
- **VirtualBox** - Primary hypervisor for Linux (full VM virtualization)
- **Libvirt** - Native Linux virtualization (KVM/QEMU) with vagrant-libvirt plugin
- **Git** - Version control system
- **Build Tools** - Essential development packages
- **UFW Firewall** - Basic security configuration

## Supported Providers

This droplet supports multiple Vagrant providers:

| Provider | Platform | Status | Notes |
|----------|----------|--------|-------|
| **VirtualBox** | Linux, macOS, Windows | ✅ Pre-installed | Default provider |
| **Libvirt** | Linux | ✅ Pre-installed | Native KVM/QEMU support |
| **VMware** | macOS, Windows | Plugin available | Requires separate VMware installation |
| **Hyper-V** | Windows | Available | Windows Server environments |

## Project Structure

```
vagrant-24-04/
├── template.json           # Packer template configuration
├── README.md              # This file
├── listing.md             # DigitalOcean Marketplace catalog copy
├── files/
│   ├── etc/              # System configuration files
│   └── var/
│       └── motd          # Message of the Day
└── scripts/
    └── vagrant.sh        # Main installation script
```

## Files

### template.json
The Packer template that defines:
- DigitalOcean builder configuration
- Provisioners for installing dependencies and Vagrant
- Environment variables and options
- Snapshot naming and region settings

### scripts/vagrant.sh
Main installation script that:
- Enables UFW firewall and configures SSH access
- Adds the HashiCorp GPG key and repository to apt
- Installs Vagrant from the official HashiCorp repository
- Verifies the installation
- Creates symbolic links for accessibility

### files/var/motd
Message of the Day file that displays:
- Welcome message and Vagrant version
- Quick start instructions
- Common Vagrant commands
- Provider information
- Useful links and system information

## Building the Image

### Prerequisites

1. **Packer** - Install from https://www.hashicorp.com/products/terraform
2. **DigitalOcean API Token** - Get from https://cloud.digitalocean.com/account/api/tokens

### Build Steps

1. Set your DigitalOcean API token:
   ```bash
   export DIGITALOCEAN_API_TOKEN="your-api-token-here"
   ```

2. Navigate to the repository root:
   ```bash
   cd /path/to/droplet-1-clicks
   ```

3. Validate the template:
   ```bash
   packer validate vagrant-24-04/template.json
   ```

4. Build the snapshot:
   ```bash
   packer build vagrant-24-04/template.json
   ```

The build process will:
- Spin up a temporary Ubuntu 24.04 Droplet
- Install Vagrant and all dependencies
- Run cleanup operations
- Create a snapshot with a timestamped name
- Remove the temporary Droplet

### Build Output

After a successful build, Packer will display:
- The snapshot ID
- The snapshot name (format: `vagrant-24-04-snapshot-{timestamp}`)
- The region where the snapshot was created

You can then use this snapshot to create new 1-Click Droplets in the DigitalOcean Marketplace.

## Multi-OS Vagrant Examples

### Quick Reference: Multi-OS Vagrantfile

This Vagrantfile demonstrates how to define and manage multiple operating systems:

```ruby
Vagrant.configure("2") do |config|

  # Ubuntu VM
  config.vm.define "ubuntu_vm" do |vm|
    vm.vm.box = "ubuntu/jammy64"
    vm.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = 2048
      vb.cpus = 2
    end
  end

  # Debian VM
  config.vm.define "debian_vm" do |vm|
    vm.vm.box = "debian/bookworm64"
    vm.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = 2048
      vb.cpus = 2
    end
  end

  # CentOS VM
  config.vm.define "centos_vm" do |vm|
    vm.vm.box = "centos/7"
    vm.vm.provider "virtualbox" do |vb|
      vb.gui = false
      vb.memory = 2048
      vb.cpus = 2
    end
  end

  # Windows 10 VM
  config.vm.define "windows_vm" do |vm|
    vm.vm.box = "gusztavvargadr/windows-10"
    vm.vm.provider "virtualbox" do |vb|
      vb.gui = true        # Windows needs GUI
      vb.memory = 4096
      vb.cpus = 2
    end
    vm.vm.communicator = "winrm"
  end

end
```

### Common Commands for Multi-OS Setup

```bash
# Start specific VM
vagrant up ubuntu_vm
vagrant up debian_vm
vagrant up centos_vm
vagrant up windows_vm

# Check status
vagrant status

# Connect to VMs
vagrant ssh ubuntu_vm
vagrant ssh debian_vm
vagrant ssh centos_vm
vagrant rdp windows_vm

# Stop and destroy
vagrant halt
vagrant destroy
```

## Configuration

### System Components

The builder installs:
- **Vagrant** - Latest stable version
- **VirtualBox** - Full VM hypervisor for Linux
- **Libvirt/KVM** - Native Linux virtualization with vagrant-libvirt plugin
- **Git** - Version control system
- **Build Tools** - Essential build packages for development
- **UFW** - Uncomplicated Firewall for security
- **Standard Utilities** - curl, wget, jq, unzip, and more

### Vagrant Version

The application version is set in `template.json` using the `application_version` variable.

To use a different version, modify this value in the template before building.

### Firewall Configuration

The builder enables UFW with the following rules:
- SSH access limited to prevent brute-force attacks
- HTTP/HTTPS ports not pre-configured (users can add as needed)
- All outbound traffic allowed

## Development Environment

This droplet is optimized for developers who need:
- A consistent development environment across team members
- Infrastructure as Code tooling
- Support for multiple virtual machine providers
- Easy provisioning and configuration management

## Customization

### Adding Additional Software

To add additional packages during build:

1. Edit `scripts/vagrant.sh`
2. Add your installation commands in the appropriate section
3. Rebuild using `packer build vagrant-24-04/template.json`

### Modifying the MOTD

Edit `files/var/motd` to customize the welcome message shown when users SSH into the droplet.

### Updating Vagrant Version

1. Check the latest version at https://developer.hashicorp.com/vagrant/install
2. Update `application_version` in `template.json`
3. Rebuild the snapshot

## Troubleshooting

### Build Fails During APT Update
Ensure your DigitalOcean API token is valid and that you have sufficient quota in your account.

### Vagrant Installation Fails
The installation relies on the HashiCorp APT repository. Check that:
- Your internet connection is working
- The repository URL is accessible from the Droplet
- The GPG key download is successful

### Snapshot Creation Fails
Ensure you have enough disk space in your DigitalOcean account for the snapshot.

## Support

For issues or questions:
- **Vagrant Documentation**: https://developer.hashicorp.com/vagrant/docs
- **GitHub Issues**: https://github.com/hashicorp/vagrant/issues
- **Community Discussion**: https://discuss.hashicorp.com/c/vagrant/

---

Created for DigitalOcean Marketplace 1-Click Applications
