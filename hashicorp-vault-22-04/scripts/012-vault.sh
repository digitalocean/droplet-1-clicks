#!/bin/bash

# non-interactive install
export DEBIAN_FRONTEND=noninteractive

# Install hashicorp vault
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Allow elasticsearch port
ufw limit ssh
ufw allow 8200

ufw --force enable

