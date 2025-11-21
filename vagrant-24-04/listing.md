# Vagrant 1-Click Application

Deploy Vagrant, HashiCorp's open-source tool for building and managing virtual machine environments. Vagrant provides a simple workflow for provisioning development environments locally or in the cloud with infrastructure as code.

## What is Vagrant?

Vagrant is a tool for building and managing virtual machine environments in a single workflow. It uses infrastructure as code to configure, provision, and manage virtual machines across multiple platforms. Vagrant:

- **Infrastructure as Code** - Define your virtual machines using Vagrantfiles
- **Multi-Platform Support** - Works with VirtualBox, VMware, Hyper-V, Docker, and more
- **Automatic Provisioning** - Automatically configure and provision machines
- **Consistent Environments** - Create identical development environments across team members
- **Version Control** - Track your infrastructure configuration in version control
- **Plugin System** - Extend Vagrant with custom providers and provisioners
- **Snapshot & Clone** - Save and restore machine states

## Key Features

- Simple, declarative configuration via Vagrantfile
- Support for multiple hypervisors and providers
- Automatic provisioning with shell scripts, Ansible, Chef, Puppet, and more
- Synced folders for seamless file sharing between host and guest
- Network configuration for port forwarding and private networks
- Box management and Vagrant Cloud integration
- Multi-machine environments in a single Vagrantfile
- Networking features including private networks, public networks, and port forwarding

## System Requirements

Vagrant requires a hypervisor to run virtual machines. This droplet comes with Vagrant pre-installed and configured.

### Recommended Droplet Sizes

| Use Case | RAM | CPU | Storage |
|----------|-----|-----|---------|
| Single Development Environment | 2GB | 1 vCPU | 40GB |
| Multiple VMs / Heavier Workloads | 4GB | 2 vCPU | 80GB |
| Team Development / CI/CD | 8GB+ | 4+ vCPU | 160GB+ |

## Pre-Installed Providers

This droplet comes with support for multiple Vagrant providers, allowing you to choose the best hypervisor for your use case:

### VirtualBox (Primary/Default)
- **Status:** Pre-installed and ready to use
- **Best For:** Linux developers, cross-platform development
- **Performance:** Full virtualization with excellent compatibility
- **Use:** `vagrant up` (default) or `vagrant up --provider=virtualbox`

### Libvirt (KVM/QEMU)
- **Status:** Pre-installed with vagrant-libvirt plugin
- **Best For:** Linux-native virtualization, performant lightweight VMs
- **Performance:** Native Linux hypervisor, efficient resource usage
- **Use:** `vagrant up --provider=libvirt`

### VMware (Fusion/Workstation)
- **Status:** Plugin available (requires separate VMware installation)
- **Best For:** Enterprise environments, VMware integration
- **Installation:** `vagrant plugin install vagrant-vmware-desktop`
- **Use:** `vagrant up --provider=vmware_desktop`

### Hyper-V
- **Status:** Available for Windows hosts
- **Best For:** Windows Server environments
- **Use:** `vagrant up --provider=hyperv`

## Getting Started

### Quick Start with VirtualBox (Recommended)

1. **Deploy the Droplet** - Select this 1-Click App from the DigitalOcean Marketplace
2. **Connect via SSH** - Connect to your droplet: `ssh root@your-droplet-ip`
3. **Verify Installation** - Check Vagrant is working: `vagrant --version`
4. **Verify VirtualBox is installed**: `VBoxManage --version`
5. **Create Your First Project**:
   ```bash
   mkdir my-vagrant-project
   cd my-vagrant-project
   vagrant init ubuntu/jammy64
   vagrant up
   vagrant ssh
   ```

### Creating a Vagrantfile

Create a simple `Vagrantfile` to define your virtual machine:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  
  # Configure networking
  config.vm.network "private_network", ip: "192.168.33.10"
  
  # Sync folders
  config.vm.synced_folder "./data", "/vagrant_data"
  
  # Provisioning with shell script
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y nginx
  SHELL
end
```

### Managing Your Virtual Machines

#### Starting a Machine
```bash
cd your-vagrant-project
vagrant up
```

#### Accessing the Machine
```bash
vagrant ssh
```

#### Stopping the Machine
```bash
vagrant halt           # Stop the machine (can be resumed)
vagrant suspend        # Suspend to RAM (faster to resume)
```

#### Restarting the Machine
```bash
vagrant reload         # Restart and re-provision
vagrant reload --provision  # Reload with provisioning
```

#### Destroying the Machine
```bash
vagrant destroy        # Remove the machine completely
```

#### Checking Status
```bash
vagrant status         # Check current machine status
vagrant global-status  # Check all machines on your system
```

## Common Use Cases

### Web Development
Use Vagrant to create a development environment that matches your production server exactly:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y nginx postgresql nodejs npm
  SHELL
end
```

### Multi-Machine Setups
Define multiple machines for testing distributed systems:

```ruby
Vagrant.configure("2") do |config|
  config.vm.define "web" do |web|
    web.vm.box = "ubuntu/jammy64"
  end
  
  config.vm.define "db" do |db|
    db.vm.box = "ubuntu/jammy64"
  end
end
```

## VirtualBox Provider (Default)

VirtualBox is the default provider on this droplet and offers full VM capabilities:

1. **Find a Vagrant box** from [Vagrant Cloud](https://app.vagrantup.com/boxes/search):
   ```bash
   vagrant init ubuntu/jammy64
   ```

2. **Create a Vagrantfile with VirtualBox configuration**:
   ```ruby
   Vagrant.configure("2") do |config|
     config.vm.box = "ubuntu/jammy64"
     
     # Configure networking
     config.vm.network "private_network", ip: "192.168.33.10"
     
     # Sync folders
     config.vm.synced_folder "./data", "/vagrant_data"
     
     # Provisioning with shell script
     config.vm.provision "shell", inline: <<-SHELL
       apt-get update
       apt-get install -y nginx
     SHELL
   end
   ```

3. **Launch the VM**:
   ```bash
   vagrant up
   vagrant ssh
   ```

## Libvirt Provider (Linux Native)

For better performance on Linux systems, use Libvirt (KVM/QEMU):

1. **Create a Vagrantfile with Libvirt provider**:
   ```ruby
   Vagrant.configure("2") do |config|
     config.vm.box = "generic/ubuntu2204"  # Use a libvirt-compatible box
     
     config.vm.provider "libvirt" do |libvirt|
       libvirt.driver = "kvm"
       libvirt.cpus = 2
       libvirt.memory = 2048
     end
   end
   ```

2. **Launch with Libvirt**:
   ```bash
   vagrant up --provider=libvirt
   ```

This provides native Linux virtualization with better performance than VirtualBox.

## Updating Vagrant

To update Vagrant to the latest version:

```bash
apt update
apt install --only-upgrade vagrant
```

Verify the update:
```bash
vagrant --version
```

## Useful Resources

- **Official Documentation**: https://developer.hashicorp.com/vagrant/docs
- **Vagrant Cloud (Public Boxes)**: https://app.vagrantup.com/boxes/search
- **Getting Started Guide**: https://developer.hashicorp.com/vagrant/tutorials
- **Community Plugins**: https://github.com/hashicorp/vagrant/wiki/Available-Vagrant-Plugins
- **GitHub Repository**: https://github.com/hashicorp/vagrant

## Troubleshooting

### SSH Key Issues
If you encounter SSH connection issues, Vagrant can generate new keys:
```bash
vagrant reload --provision
```

### Provider Issues
Check that your provider is correctly configured:
```bash
vagrant global-status
vagrant provider list
```

### Provisioning Failures
Re-run provisioners:
```bash
vagrant provision
```

### Clean Start
Remove and recreate a machine:
```bash
vagrant destroy
vagrant up
```

## Post-Deployment

After deploying this droplet, you can immediately start using Vagrant to define and manage virtual machines. The installation includes:

- **Vagrant 2.4.9** - Latest stable release
- **Essential Tools** - Git, build tools, and required dependencies
- **Pre-configured UFW** - Basic firewall rules for security

Your droplet is ready to host Vagrant projects. Start by creating your first Vagrantfile or cloning an existing project repository.

---

**Need Help?** Visit the [Vagrant Documentation](https://developer.hashicorp.com/vagrant/docs) or check the [Community Forum](https://discuss.hashicorp.com/c/vagrant/).
