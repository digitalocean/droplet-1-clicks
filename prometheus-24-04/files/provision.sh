#!/bin/bash

# Update package lists and upgrade packages
sudo apt -qqy update
sudo apt -qqy -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' full-upgrade
sudo apt-get -qqy clean

# Create system group and user for Prometheus
sudo groupadd --system prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus

# Create required directories
sudo mkdir -p /etc/prometheus /var/lib/prometheus

# Download and extract Prometheus
curl -sSL https://github.com/prometheus/prometheus/releases/download/v2.54.1/prometheus-2.54.1.linux-amd64.tar.gz | tar -xz

# Move Prometheus binaries to /usr/local/bin
sudo mv /root/prometheus*/{prometheus,promtool} /usr/local/bin

# Change ownership of the Prometheus binaries
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Move configuration files and change ownership
sudo mv /root/prometheus*/{consoles,console_libraries,prometheus.yml} /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable and start the Prometheus service
sudo systemctl enable prometheus
sudo systemctl start prometheus


#Clean up
sleep 5
sudo apt-get -qqy clean