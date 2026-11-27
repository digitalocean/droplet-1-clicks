# Coolify 1-Click Droplet Builder

This directory contains the Packer builder configuration for creating a Coolify 1-Click DigitalOcean Droplet image.

## Overview

Coolify is an open-source, self-hostable platform that simplifies deploying and managing applications, databases, and services on your own server. It's a powerful alternative to platforms like Heroku, Netlify, and Vercel, giving you complete control over your infrastructure and data.

This builder creates a fully configured Ubuntu 24.04 LTS Droplet with:
- Docker Engine 24+ (official installation)
- Coolify platform (latest version)
- Pre-configured firewall with UFW
- Systemd service for automatic startup
- Management scripts for easy administration
- Automated first-boot setup

## Directory Structure

```
coolify-24-04/
├── template.json                    # Packer build configuration
├── README.md                        # This file
├── listing.md                       # Marketplace catalog copy
├── scripts/
│   └── 010-coolify.sh              # Main installation script
└── files/
    ├── etc/
    │   └── update-motd.d/
    │       └── 99-one-click         # Message of the Day
    └── var/
        └── lib/
            └── cloud/
                └── scripts/
                    └── per-instance/
                        └── 001_onboot  # First-boot configuration script
```

## Build Requirements

### Prerequisites

1. **Packer**: Install Packer from https://www.packer.io/downloads
2. **DigitalOcean API Token**: Generate a token with write access from https://cloud.digitalocean.com/account/api/tokens
3. **DigitalOcean Account**: Active account with sufficient quota for droplet creation

### Environment Setup

Export your DigitalOcean API token:

```bash
export DIGITALOCEAN_API_TOKEN="your_api_token_here"
```

## Building the Image

### From the Repository Root

```bash
# Initialize Packer plugins (first time only)
packer init config/plugins.pkr.hcl

# Validate the template
packer validate coolify-24-04/template.json

# Build the image
packer build coolify-24-04/template.json
```

### Build Process

The build process takes approximately 10-15 minutes and includes:

1. **Base System Setup** (2-3 minutes)
   - Ubuntu 24.04 LTS droplet creation
   - System updates and package installation
   - Essential utilities (curl, git, jq, openssl, etc.)

2. **Docker Installation** (3-4 minutes)
   - Official Docker Engine 24+ from Docker's apt repository
   - Docker Compose plugin
   - Docker daemon configuration for logging

3. **Coolify Preparation** (2-3 minutes)
   - Directory structure creation
   - Configuration file downloads
   - Security value generation
   - Helper script creation
   - First-login setup script preparation

4. **Systemd Service Setup** (1 minute)
   - Service file creation
   - Service enablement for auto-start

5. **Finalization** (2-3 minutes)
   - Common security scripts
   - Cleanup and optimization
   - Snapshot creation

## What Gets Installed

### System Packages

- **Docker Engine 24+**: Container runtime
- **Docker Compose**: Multi-container orchestration
- **UFW**: Uncomplicated Firewall
- **curl, wget**: File transfer utilities
- **git**: Version control
- **jq**: JSON processing
- **openssl**: Cryptographic operations

### Coolify Components

Coolify itself is installed on first boot and includes:
- Coolify web interface (port 8000)
- PostgreSQL database
- Redis cache
- Soketi WebSocket server
- Traefik reverse proxy

### Directory Structure Created

```
/data/coolify/
├── source/                          # Coolify source and configuration
│   ├── .env                        # Environment variables
│   ├── docker-compose.yml          # Main compose file
│   ├── docker-compose.prod.yml     # Production overrides
│   └── upgrade.sh                  # Update script
├── ssh/
│   ├── keys/                       # SSH keys for server management
│   └── mux/                        # SSH multiplexing
├── applications/                    # Deployed applications
├── databases/                       # Database data
├── backups/                        # Backup storage
├── services/                       # Additional services
├── proxy/                          # Traefik configuration
│   └── dynamic/
└── webhooks-during-maintenance/    # Webhook queue
```

### Management Scripts

Located in `/opt/`:

- **start-coolify.sh**: `systemctl start coolify`
- **stop-coolify.sh**: `systemctl stop coolify`
- **restart-coolify.sh**: `systemctl restart coolify` (recreates stack after stop)
- **update-coolify.sh**: Update to latest Coolify version
- **coolify-logs.sh**: View real-time logs
- **coolify-status.sh**: Check systemd + container status
- **configure-coolify-localhost.sh**: Repair localhost SSH trust and force SSH port 22

### Systemd Service

- **Service Name**: coolify.service
- **Status**: Enabled (auto-starts on boot)
- **Control**: `systemctl {start|stop|restart|status} coolify`

## First Boot Behavior

When a droplet is created from this image:

1. **SSH Configuration**: Removes forced logout for root user
2. **SSH Key Generation**: Generates unique Coolify localhost keys (`-C coolify`) and authorizes them in `/etc/ssh/authorized_keys.d/coolify`
3. **Coolify Installation**: Starts Coolify via `systemctl enable --now coolify`
4. **Service Startup**: Waits for containers to be ready; systemd unit is active
5. **Localhost SSH sync**: Runs `/opt/coolify-sync-localhost-ssh.sh` and marks trust configured only if a real host SSH check passes (soft-fail continues first boot if not)
6. **Information File**: Creates `/root/coolify_info.txt` with access details (success vs repair messaging)
7. **MOTD Display**: Shows access information on SSH login

Marketplace safety (follow-up to [#509](https://github.com/digitalocean/droplet-1-clicks/pull/509) / MP-9232): Packer cleanup still wipes `/root/.ssh/authorized_keys` at **image build** time. First-boot localhost trust from #509 is kept, but written to `/etc/ssh/authorized_keys.d/coolify` (`Match User root` sshd drop-in) so Vendor Portal `img_check` still sees an empty `~/.ssh/authorized_keys` while Validate keeps working.

## First Login Experience

On first SSH login, users see a one-time notice that reports whether localhost SSH trust was verified.

Localhost SSH trust is attempted/verified on first boot (SSH port **22** for Validate; UI stays `:8000`). Soft-fail first boot can leave localhost unverified.

- **SSH for Validate**: port **22** only — do not set Servers → SSH port to 8000 or 8080
- **Coolify UI**: `http://droplet-ip:8000`
- If Servers → localhost is Unavailable / `Permission denied (publickey)`, or first-login says trust was not verified, run:
  ```bash
  /opt/configure-coolify-localhost.sh
  ```
  then Validate again with SSH port 22

## Network Configuration

### Firewall Rules (UFW)

The following ports are automatically configured:

| Port | Service | Description |
|------|---------|-------------|
| 22 | SSH | Rate-limited; also allowed from Docker bridges for Coolify localhost |
| 80 | HTTP | Web traffic and Let's Encrypt |
| 443 | HTTPS | Secure web traffic |
| 8000 | Coolify UI | Web interface |
| 6001 | Realtime | Real-time updates |
| 6002 | Soketi | WebSocket server |

### Docker Network

- **Network Name**: coolify
- **Type**: Bridge, attachable
- **Purpose**: Container isolation and communication

## Security Considerations

### Pre-configured Security

1. **Firewall**: UFW enabled with minimal open ports
2. **SSH**: Rate limiting on port 22
3. **Secrets**: Auto-generated secure random values
4. **Permissions**: Proper file permissions on sensitive directories
5. **Docker**: Configured logging limits to prevent disk exhaustion

### Post-Deployment Security

Users should:
1. Create admin account immediately after first access
2. Configure SSH key authentication
3. Disable password authentication
4. Enable 2FA in Coolify
5. Use custom domains with HTTPS
6. Regular updates via `/opt/update-coolify.sh`

## Customization

### Modifying the Build

To customize the installation:

1. **Change Docker version**: Edit `scripts/010-coolify.sh` Docker installation section
2. **Adjust firewall rules**: Modify UFW commands in `scripts/010-coolify.sh`
3. **Add packages**: Update `apt_packages` in `template.json`
4. **Custom scripts**: Add scripts to `scripts/` directory and reference in `template.json`

### Environment Variables

Coolify can be customized via environment variables in `/data/coolify/source/.env`:

- **APP_ID**: Application identifier
- **APP_KEY**: Encryption key
- **DB_PASSWORD**: Database password
- **REDIS_PASSWORD**: Redis password
- Various Pusher settings for real-time features

See Coolify documentation for full list: https://coolify.io/docs

## Testing the Build

### Manual Testing Steps

1. **Create a droplet** from the built snapshot
2. **Wait 3-5 minutes** for first-boot completion
3. **SSH into the droplet**: `ssh root@droplet-ip`
4. **Check MOTD**: Verify access instructions and SSH port 22 / repair guidance
5. **Check Coolify status**: Run `/opt/coolify-status.sh` — systemd should be `active`
6. **Access web interface**: Visit `http://droplet-ip:8000`
7. **Create admin account**: Register first user
8. **Validate localhost**: Servers → localhost → SSH port **22** → Validate (green); if Unavailable / publickey, run `/opt/configure-coolify-localhost.sh` and retry
9. **Lifecycle**: `/opt/stop-coolify.sh` then `/opt/restart-coolify.sh` — UI reachable again; `systemctl is-active coolify` is `active`
10. **Deploy test application**: Try deploying a simple static site

### Automated Tests

```bash
# Check if Docker is installed
docker --version

# Check if Coolify containers are running
docker ps | grep coolify

# Check systemd service is active (not just enabled)
systemctl is-active coolify
systemctl status coolify

# Localhost SSH trust (Coolify keys live outside ~/.ssh/authorized_keys)
grep coolify /etc/ssh/authorized_keys.d/coolify
# img_check path must stay Coolify-free:
! grep -E '(root@)?coolify|cpk:' /root/.ssh/authorized_keys 2>/dev/null
ssh -i /data/coolify/ssh/keys/id.root@host.docker.internal \
  -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@127.0.0.1 true

# UI listening
ss -lntp | grep ':8000'

# Firewall rules (includes Docker → SSH allows)
ufw status

# Check directory structure
ls -la /data/coolify/

# Check helper scripts
ls -l /opt/*coolify*.sh

# Stop then restart must restore :8000
/opt/stop-coolify.sh
/opt/restart-coolify.sh
systemctl is-active coolify
ss -lntp | grep ':8000'
```

## Troubleshooting Build Issues

### Common Problems

**Docker installation fails:**
- Check internet connectivity during build
- Verify Docker GPG key URL is accessible
- Check Ubuntu version is 24.04 LTS

**Packer timeout:**
- Increase timeout in template.json
- Check DigitalOcean API rate limits
- Verify droplet size has sufficient resources

**Script execution errors:**
- Check script permissions (should be executable)
- Review script syntax with `shellcheck`
- Examine Packer build logs

### Debug Mode

Enable debug output:

```bash
PACKER_LOG=1 packer build coolify-24-04/template.json
```

## Maintenance and Updates

### Updating Coolify Version

Coolify automatically pulls the latest version on first boot. To update an existing installation:

```bash
/opt/update-coolify.sh
```

Or manually:

```bash
cd /data/coolify/source
bash upgrade.sh
```

### Rebuilding the Image

Rebuild monthly or when:
- Ubuntu releases security updates
- Docker releases major updates
- Coolify has breaking changes requiring new setup

## Version Compatibility

### Tested Versions

- **Ubuntu**: 24.04 LTS
- **Docker Engine**: 24.0+
- **Docker Compose**: 2.20+
- **Coolify**: Latest stable (auto-updated)
- **Packer**: 1.9+

### Known Compatibility Issues

- **Ubuntu 24.10**: Non-LTS versions not supported by Coolify quick install
- **Docker Snap**: Not supported, must use official Docker installation
- **ARM64**: Supported on compatible droplets

## Resource Requirements

### Minimum (Coolify only)

- **CPU**: 2 cores
- **RAM**: 2 GB
- **Disk**: 30 GB
- **Network**: Standard DigitalOcean networking

### Recommended (with applications)

- **CPU**: 4+ cores
- **RAM**: 8+ GB
- **Disk**: 100+ GB SSD
- **Network**: Standard with monitoring enabled

## Support and Documentation

### Coolify Resources

- **Official Docs**: https://coolify.io/docs
- **Discord Community**: https://coolify.io/discord
- **GitHub**: https://github.com/coollabsio/coolify
- **YouTube**: https://www.youtube.com/@coolify-io

### DigitalOcean Resources

- **1-Click Apps**: https://marketplace.digitalocean.com/
- **Developer Guide**: See DEVELOPER-GUIDE.md in repository root
- **Community**: https://www.digitalocean.com/community

## Contributing

To contribute improvements to this builder:

1. Fork the repository
2. Make your changes
3. Test the build thoroughly
4. Submit a pull request with detailed description

### Code Style

- Use shellcheck for bash scripts
- Follow existing directory structure
- Document all customizations
- Test on fresh Ubuntu 24.04 installation

## License

This builder configuration follows the same license as the droplet-1-clicks repository.

Coolify itself is licensed under Apache License 2.0.

## Changelog

### Version 1.0 (Initial Release)

- Ubuntu 24.04 LTS base
- Docker Engine 24+ official installation
- Coolify latest version
- Automated first-boot setup
- Systemd service integration
- Management helper scripts
- Pre-configured firewall
- Comprehensive documentation

---

**Built with**: Packer, Docker, and ❤️ for the developer community

**Maintained by**: DigitalOcean Marketplace Team
