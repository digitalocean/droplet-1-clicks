#!/bin/bash 

echo "***********************************"
echo "First Run Pocketbase"
echo "***********************************"

# enable and start service
systemctl enable pocketbase.service
systemctl start pocketbase
