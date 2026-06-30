#!/bin/sh

code_server_version=${CODE_SERVER_VERSION}
arch=${ARCH}
code_server_archive="code-server-${code_server_version}-linux-${arch}.tar.gz"
code_server_installer_url="https://github.com/coder/code-server/releases/download/v${code_server_version}/${code_server_archive}"
code_server_path=/tmp/code-server

# Fetch and extract the code-server archive
wget -P ${code_server_path} ${code_server_installer_url}
tar -xzvf ${code_server_path}/${code_server_archive} -C ${code_server_path}

# Copy binaries
sudo cp -r ${code_server_path}/code-server-${code_server_version}-linux-${arch}/ /usr/lib/code-server
sudo ln -s /usr/lib/code-server/bin/code-server /usr/bin/code-server
sudo mkdir /var/lib/code-server

# Configure Nginx
rm -rvf /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/digitalocean \
      /etc/nginx/sites-enabled/digitalocean