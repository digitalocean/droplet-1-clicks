#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

wget https://releases.hashicorp.com/vault/1.14.8/vault_1.14.8_linux_amd64.zip
unzip vault_1.14.8_linux_amd64.zip
sudo mv vault /usr/bin
mkdir /vault
mkdir /vault/data
groupadd vault
useradd --system --shell /usr/sbin/nologin --home /vault -g vault vault
chown -R vault:vault /vault
sudo swapoff -a # turn off swap

sudo systemctl disable apport.service # turn off core dump
echo "root            hard    core            0" >> /etc/security/limits.conf


cat >> /root/.bashrc <<EOM
# generate token and keys
echo "HashiCorp Vault is being initialized"
sleep 5
vault operator init -address=http://127.0.0.1:8200 > /.digitalocean_vault_tokens.txt
cp -f /etc/skel/.bashrc /root/.bashrc
ufw allow 8200
ufw --force enable
echo "HashiCorp Vault is successfully initialized"
EOM

ufw limit ssh
ufw --force enable

