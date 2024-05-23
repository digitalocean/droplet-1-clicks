#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

wget https://releases.hashicorp.com/consul/1.17.3/consul_1.17.3_linux_amd64.zip
unzip consul_1.17.3_linux_amd64.zip
sudo mv consul /usr/bin

wget https://releases.hashicorp.com/vault/1.14.8/vault_1.14.8_linux_amd64.zip
unzip vault_1.14.8_linux_amd64.zip
sudo mv vault /usr/bin

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

# Allow elasticsearch port
ufw limit ssh
ufw --force enable

