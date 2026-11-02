#!/bin/bash
set -euo pipefail

# open port for clients
ufw allow 5672
# open port for rabbitmq_management (UI plugin)
ufw allow 15672

sudo apt-get install curl gnupg apt-transport-https -y

## Team RabbitMQ's signing key
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null

## Add apt repositories maintained by Team RabbitMQ.
## ppa1/ppa2.rabbitmq.com were shut down; deb1/deb2 are the current mirrors.
## https://www.rabbitmq.com/blog/2025/07/16/debian-apt-repositories-are-moving
sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
## Modern Erlang/OTP releases
##
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-erlang/ubuntu/noble noble main
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb2.rabbitmq.com/rabbitmq-erlang/ubuntu/noble noble main

## Latest RabbitMQ releases
##
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-server/ubuntu/noble noble main
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb2.rabbitmq.com/rabbitmq-server/ubuntu/noble noble main
EOF

## Prefer Team RabbitMQ packages over Ubuntu's rabbitmq-server (3.12.1 on Noble).
sudo tee /etc/apt/preferences.d/rabbitmq <<EOF
Package: erlang*
Pin: origin RabbitMQ
Pin-Priority: 1001

Package: rabbitmq-server
Pin: origin RabbitMQ
Pin-Priority: 1001
EOF

## Update package indices
sudo apt-get update -y

## Install Erlang packages. Do not install the Ubuntu "erlang" metapackage;
## it does not pin dependency versions and pulls Erlang that cannot run RabbitMQ 4.x.
sudo apt-get install -y erlang-base \
                        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                        erlang-runtime-tools erlang-snmp erlang-ssl \
                        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

## Install the latest rabbitmq-server from Team RabbitMQ's repository.
sudo apt-get install rabbitmq-server -y --fix-missing

installed="$(dpkg-query -W -f '${Version}' rabbitmq-server)"
echo "Installed rabbitmq-server ${installed}"

## Enable management UI plugin
sudo rabbitmq-plugins enable rabbitmq_management
