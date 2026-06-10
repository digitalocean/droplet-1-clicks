#!/bin/bash
set -e

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

# Add a swap file to prevent build time OOM errors
fallocate -l 8G /swapfile
mkswap /swapfile
swapon /swapfile

# Retrieve the latest package versions across all repositories and install
# repository/bootstrap tools. Jitsi packages pull the correct Noble dependency
# set, so avoid pinning old Ubuntu dependency package names here.
apt-get -qqy update
apt-get -qqy -o Dpkg::Options::=--force-confdef install \
 apt-transport-https ca-certificates curl gnupg2 software-properties-common \
 lsb-release debconf-utils

# Jitsi requires dependencies from Ubuntu's universe package repository
add-apt-repository -y universe
apt-get -qqy update

# Add the Prosody package repository
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://prosody.im/files/prosody-debian-packages.key | \
  gpg --dearmor --yes -o /etc/apt/keyrings/prosody-debian-packages.gpg
echo "deb [signed-by=/etc/apt/keyrings/prosody-debian-packages.gpg] http://packages.prosody.im/debian $(lsb_release -sc) main" > /etc/apt/sources.list.d/prosody-debian-packages.list
cat > /etc/apt/preferences.d/prosody-pin <<'EOF'
Package: prosody*
Pin: origin packages.prosody.im
Pin-Priority: 1001
EOF


# First install the Jitsi repository key onto your system:
curl -fsSL https://download.jitsi.org/jitsi-key.gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/jitsi-keyring.gpg

# Create a sources.list.d file with the repository:
echo "deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/" > /etc/apt/sources.list.d/jitsi-stable.list

# update apt
apt-get -qqy -o Dpkg::Options::=--force-confdef update
apt-get -qqy -o Dpkg::Options::=--force-confdef upgrade
apt-get -qqy -o Dpkg::Options::=--force-confdef install \
 lua5.3 openjdk-17-jre-headless nginx-full

JITSI_HOSTNAME="${JITSI_HOSTNAME:-jitsi.localhost}"
echo "jitsi-videobridge jitsi-videobridge/jvb-hostname string ${JITSI_HOSTNAME}" | debconf-set-selections
echo "jitsi-videobridge2 jitsi-videobridge/jvb-hostname string ${JITSI_HOSTNAME}" | debconf-set-selections
echo "jitsi-meet-prosody jitsi-videobridge/jvb-hostname string ${JITSI_HOSTNAME}" | debconf-set-selections
echo "jitsi-meet-prosody jitsi-meet-prosody/jvb-hostname string ${JITSI_HOSTNAME}" | debconf-set-selections
echo "jitsi-meet jitsi-meet/jvb-hostname string ${JITSI_HOSTNAME}" | debconf-set-selections
echo "jitsi-meet jitsi-meet/jaas-choice boolean false" | debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/jvb-hostname string ${JITSI_HOSTNAME}" | debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/jaas-choice boolean false" | debconf-set-selections
echo "jitsi-meet-prosody jitsi-meet/jaas-choice boolean false" | debconf-set-selections
echo "jitsi-meet jitsi-meet/cert-choice select Generate a new self-signed certificate" | debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/cert-choice select Generate a new self-signed certificate" | debconf-set-selections

# Install Jitsi during image build. Domain-specific certificate setup remains
# in /var/complete-jitsi-setup.sh because it depends on the final Droplet DNS.
apt-get -qqy -o Dpkg::Options::=--force-confdef install \
 jicofo jitsi-meet jitsi-meet-prosody jitsi-meet-turnserver \
 jitsi-meet-web jitsi-meet-web-config jitsi-videobridge2

# install let's encrypt
apt-get -qqy -o Dpkg::Options::=--force-confdef install python3-certbot-nginx

# add some security
apt-get -qqy -o Dpkg::Options::=--force-confdef install fail2ban
systemctl start fail2ban
systemctl enable fail2ban
printf '[sshd]\nenabled = true\nport = 22\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5' | tee -a /etc/fail2ban/jail.local
printf '\n\n[http-auth]\nenabled = true\nport = http,https\nlogpath = /var/log/auth.log\nmaxretry = 5' | tee -a /etc/fail2ban/jail.local
systemctl restart fail2ban

# open ports
ufw limit ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3478/udp
ufw allow 4443/tcp
ufw allow 10000/udp
ufw allow 5349/tcp
ufw --force enable

# Disable and remove the swapfile prior to snapshotting
swapoff /swapfile
rm -f /swapfile

