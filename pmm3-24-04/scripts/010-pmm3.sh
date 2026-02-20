#!/bin/bash
set -e

# Create directories for PMM3
mkdir -p /opt/pmm3

# Download and install PMM3 using the official script
echo "Downloading PMM3 installer..."
curl -fsSL https://raw.githubusercontent.com/percona/pmm/refs/heads/v3/get-pmm.sh -o /opt/pmm3/get-pmm.sh
chmod +x /opt/pmm3/get-pmm.sh

# Run PMM3 installer
echo "Installing PMM3..."
cd /opt/pmm3
/bin/bash get-pmm.sh

# Create first-login setup script
cat > /opt/pmm3/setup.sh << 'EOF'
#!/bin/bash

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}=================================================================${NC}"
echo -e "${GREEN}Welcome to Percona Monitoring and Management 3 (PMM3)${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""
echo -e "PMM3 has been installed and is ready to use!"
echo ""
echo -e "${YELLOW}Access Information:${NC}"
echo "  • Web Interface: https://$(curl -s ifconfig.me):443"
echo "  • Default Username: admin"
echo "  • Default Password: admin"
echo ""
echo -e "${RED}Important Security Notes:${NC}"
echo "  1. Please change the default admin password immediately!"
echo "  2. Consider setting up SSL/TLS certificates for production use"
echo "  3. Configure firewall rules as needed for your environment"
echo ""
echo -e "${YELLOW}PMM3 Features:${NC}"
echo "  • Real-time monitoring and alerting"
echo "  • Query Analytics and optimization"
echo "  • Database performance insights"
echo "  • Support for MySQL, PostgreSQL, MongoDB, and more"
echo ""
echo -e "${YELLOW}Getting Started:${NC}"
echo "  1. Access the web interface using the URL above"
echo "  2. Log in with admin/admin credentials"
echo "  3. Change the default password in Settings"
echo "  4. Add your databases for monitoring"
echo ""
echo -e "${YELLOW}DigitalOcean Database Integration:${NC}"
echo "  For DigitalOcean Managed Database users:"
echo "  • Run: python3 /root/pmm-do.py"
echo "  • This script automatically discovers and adds your DigitalOcean databases"
echo "  • You'll need your DigitalOcean API token"
echo "  • Optionally set environment variables to skip prompts:"
echo "    export DIGITALOCEAN_API_TOKEN=your_token_here"
echo "    export PMM_ADMIN_PASSWORD=your_pmm_password"
echo ""
echo -e "${YELLOW}Documentation:${NC}"
echo "  • Official Docs: https://docs.percona.com/percona-monitoring-and-management/"
echo "  • Getting Started: https://docs.percona.com/percona-monitoring-and-management/get-started/"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  • Check status: systemctl status pmm-agent"
echo "  • View logs: journalctl -u pmm-agent -f"
echo "  • Configuration: /usr/local/percona/pmm2/"
echo ""
echo -e "${YELLOW}Security Information:${NC}"
echo "To keep this Droplet secure, the UFW firewall is enabled."
echo "Ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) are open."
echo "PMM3 uses HTTPS by default for secure communication."
echo -e "${RED}Recommendation:${NC} For improved security, consider:"
echo "  • Restricting SSH access to your IP only"
echo "  • Setting up SSL/TLS certificates"
echo "  • Using DigitalOcean Cloud Firewall for additional protection"
echo ""
echo -e "${BLUE}Thank you for using PMM3 from the DigitalOcean Marketplace!${NC}"
echo ""

# Remove this script from .bashrc
sed -i '/setup.sh/d' /root/.bashrc

EOF

chmod +x /opt/pmm3/setup.sh

# Add to root's .bashrc to run on first login
echo "/opt/pmm3/setup.sh" >> /root/.bashrc

# Create per-instance startup script
mkdir -p /var/lib/cloud/scripts/per-instance
cat > /var/lib/cloud/scripts/per-instance/01-setup-pmm3.sh << 'EOF'
#!/bin/bash

# This script runs on first boot of a newly created Droplet
# to prepare the system for PMM3

# Set the hostname to 'pmm3'
hostnamectl set-hostname pmm3

# Ensure Docker is running (if PMM3 uses Docker)
systemctl enable docker
systemctl start docker

# Ensure PMM services are running
systemctl enable pmm-agent || true
systemctl start pmm-agent || true

EOF

chmod +x /var/lib/cloud/scripts/per-instance/01-setup-pmm3.sh

# Create a README file in /opt/pmm3
cat > /opt/pmm3/README.md << 'EOF'
# Percona Monitoring and Management 3 (PMM3)

Welcome to your PMM3 server! This guide will help you get started.

## What is PMM3?

Percona Monitoring and Management (PMM) is an open source database monitoring, management, and observability solution for MySQL, PostgreSQL, and MongoDB.

## Key Features

- Real-time performance monitoring
- Query Analytics for optimization
- Alerting and notification system
- Database performance insights
- Support for MySQL, PostgreSQL, MongoDB, and more
- Grafana-based dashboards
- Prometheus-based metrics collection

## Getting Started

1. Access the PMM3 web interface at: https://YOUR_SERVER_IP:443
2. Log in with the default credentials:
   - Username: admin
   - Password: admin
3. **Important**: Change the default password immediately!
4. Add your databases for monitoring

## DigitalOcean Database Integration

If you're using DigitalOcean Managed Databases, you can use the included script to automatically discover and add them to PMM:

```bash
python3 /root/pmm-do.py
```

### Prerequisites:
- DigitalOcean API token (read-only permissions sufficient)
- PMM admin password

### Environment Variables (optional):
```bash
export DIGITALOCEAN_API_TOKEN=your_token_here
export PMM_ADMIN_PASSWORD=your_pmm_password
```

The script will:
- Discover all MySQL databases in your DigitalOcean account
- Prompt you to select which ones to monitor
- Automatically configure monitoring with optimal settings
- Set up Query Analytics and performance monitoring

## Default Credentials

- **Username**: admin
- **Password**: admin

⚠️ **Security Warning**: Please change these credentials immediately after first login!

## Service Management

- Check PMM status: `systemctl status pmm-agent`
- View PMM logs: `journalctl -u pmm-agent -f`
- Configuration directory: `/usr/local/percona/pmm2/`

## Documentation

- Official Documentation: https://docs.percona.com/percona-monitoring-and-management/
- Getting Started Guide: https://docs.percona.com/percona-monitoring-and-management/get-started/
- Adding Services: https://docs.percona.com/percona-monitoring-and-management/setting-up/

## Support

- Percona Community Forum: https://forums.percona.com/
- GitHub Issues: https://github.com/percona/pmm
- Documentation: https://docs.percona.com/

## Security Recommendations

1. Change default admin password
2. Configure SSL/TLS certificates
3. Set up proper firewall rules
4. Regular security updates
5. Monitor access logs

EOF

# Copy the DigitalOcean integration script to the root directory
cp /tmp/pmm-do.py /root/pmm-do.py
chmod +x /root/pmm-do.py

echo "PMM3 installation completed." 