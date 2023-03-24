#!/bin/bash

# This script expects the token in the form of DIGITALOCEAN_ACCESS_TOKEN
export DIGITALOCEAN_ACCESS_TOKEN=''

# This script is meant to be run as a cron job once every 10min (or whatever interval you need)
# Command to add this shell script to crontab below. You must first test manually
# (crontab -l; echo "*/10 * * * * /root/nfs-whitelist.sh  >> /root/nfswhitelist_cron.log 2>&1") | sort -u | crontab -


# Set the tag name
tag_name="nfs-client"

# Get the Droplets with the specified tag 
droplets=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" "https://api.digitalocean.com/v2/droplets?tag_name=$tag_name")

# Get the IP addresses of Droplets with the specified tag
# Get the IP addresses of the Droplets
ip_addresses=$(echo $droplets | jq -r '.droplets[].networks.v4[] | select(.type=="public") | .ip_address')

# Add the IP addresses as a whitelist to UFW
for ip in $ip_addresses; do
    echo adding $ip as NFS whitelist
    ufw allow from $ip to any port nfs
done

# Enable UFW
ufw --force enable

# Check the UFW status
ufw status


