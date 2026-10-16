#!/bin/bash

echo "Starting NemoClaw setup wizard"

# Packer/umask may leave this 0755; onboard requires owner-private 0700.
mkdir -p /root/.nemoclaw
chmod 700 /root/.nemoclaw

nemoclaw onboard

cp /etc/skel/.bashrc /root

echo "You may now connect to your NemoClaw instance using 'nemoclaw <your sandbox> connect' and then connect to OpenClaw using 'openclaw tui'"
