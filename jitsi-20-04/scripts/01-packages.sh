#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive
apt-get -qqy -o Dpkg::Options::=\"--force-confdef\" -o "

# Add a swap file to prevent build time OOM errors
fallocate -l 8G /swapfile
mkswap /swapfile
swapon /swapfile

# First install the Jitsi repository key onto your system:
curl https://download.jitsi.org/jitsi-key.gpg.key | sudo sh -c 'gpg --dearmor > /usr/share/keyrings/jitsi-keyring.gpg'

# Create a sources.list.d file with the repository:
echo 'deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/' | sudo tee /etc/apt/sources.list.d/jitsi-stable.list > /dev/null

# update apt
apt-get -qqy -o Dpkg::Options::=\"--force-confdef\" update
apt-get -qqy -o Dpkg::Options::=\"--force-confdef\" upgrade

# requisites for jitsi
apt-get -qqy -o Dpkg::Options::=\"--force-confdef\" install ca-certificates-java coturn fontconfig-config fonts-dejavu-core fonts-lato java-common javascript-common\
 libavahi-client3 libavahi-common-data libavahi-common3 libcups2 libevent-core-2.1-7\
 libevent-extra-2.1-7 libevent-openssl-2.1-7 libevent-pthreads-2.1-7 libfontconfig1 libgd3 libgraphite2-3\
 libharfbuzz0b libhiredis0.14 libidn11 libjbig0 libjpeg-turbo8 libjpeg8 libjs-jquery liblcms2-2\
 libmysqlclient21 libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail\
 libnginx-mod-stream libnspr4 libnss3 libpcsclite1 libpq5 libruby2.7 libtiff5 libwebp6 libxpm4 lua-bitop\
 lua-event lua-expat lua-filesystem lua-sec lua-socket lua5.2 mysql-common nginx nginx-common nginx-core\
 openjdk-16-jre-headless prosody rake ruby ruby-hocon ruby-minitest ruby-net-telnet ruby-power-assert\
 ruby-test-unit ruby-xmlrpc ruby2.7 rubygems-integration sqlite3 ssl-cert unzip zip

# apt-get -y install debconf-utils

# echo "jitsi-videobridge2 jitsi-videobridge/jvb-hostname string example.digitalocean.com" | debconf-set-selections
# echo "jitsi-meet-web-config jitsi-meet/cert-choice select Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)" | debconf-set-selections

# install let's encrypt
apt-get -qqy -o Dpkg::Options::=\"--force-confdef\" install python3-certbot-nginx

# install Digital Ocean agent
curl -sSL https://repos.insights.digitalocean.com/install.sh | bash

# add some security
echo "y" | ufw enable
apt-get -qqy -o Dpkg::Options::=\"--force-confdef\" install fail2ban
systemctl start fail2ban
systemctl enable fail2ban
printf '[sshd]\nenabled = true\nport = 22\nfilter = sshd\nlogpath = /var/log/auth.log\nmaxretry = 5' | tee -a /etc/fail2ban/jail.local
printf '\n\n[http-auth]\nenabled = true\nport = http,https\nlogpath = /var/log/auth.log\nmaxretry = 5' | tee -a /etc/fail2ban/jail.local
systemctl restart fail2ban

# open ports
ufw allow http
ufw allow https
ufw allow ssh
ufw allow 4443/tcp
ufw allow 10000/udp

# Disable and remove the swapfile prior to snapshotting
swapoff /swapfile
rm -f /swapfile

