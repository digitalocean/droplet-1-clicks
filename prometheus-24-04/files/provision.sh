#!/bin/bash
set -euo pipefail

application_version="${application_version:?application_version is required}"

# Update package lists and upgrade packages
sudo apt -qqy update
sudo apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' full-upgrade
sudo apt-get -qqy clean

# Create system group and user for Prometheus
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus

# Create required directories
sudo mkdir -p /etc/prometheus /var/lib/prometheus /var/lib/digitalocean

# Download and extract Prometheus
curl -fsSL "https://github.com/prometheus/prometheus/releases/download/v${application_version}/prometheus-${application_version}.linux-amd64.tar.gz" | tar -xz

# Move Prometheus binaries to /usr/local/bin
sudo mv /root/prometheus*/{prometheus,promtool} /usr/local/bin

# Change ownership of the Prometheus binaries
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Move configuration files and change ownership
# Note: Prometheus 3.x no longer ships example consoles/console_libraries
sudo mv /root/prometheus*/prometheus.yml /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Remove extracted release directory
sudo rm -rf /root/prometheus-*

# Ensure MOTD script is executable
sudo chmod +x /etc/update-motd.d/99-one-click-prom

# Reload systemd and enable Prometheus for first boot (do not start during image build)
sudo systemctl daemon-reload
sudo systemctl enable prometheus

# Clean up
sudo apt-get -qqy clean
