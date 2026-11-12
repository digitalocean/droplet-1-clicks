#!/bin/bash
# Drop build-time Landscape MOTD cache so first boot regenerates customer droplet sysinfo
rm -f /var/lib/landscape/landscape-sysinfo.cache
