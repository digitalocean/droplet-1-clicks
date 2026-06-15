#!/bin/bash

echo "Starting NemoClaw setup wizard"

nemoclaw onboard

cp /etc/skel/.bashrc /root

echo "You may now connect to your NemoClaw instance using 'nemoclaw <your sandbox> connect' and then connect to OpenClaw using 'openclaw tui'"
