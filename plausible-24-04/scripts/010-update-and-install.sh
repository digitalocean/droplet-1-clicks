#!/bin/bash

apt update && sudo apt upgrade -y

apt install -y curl wget git postgresql postgresql-contrib nginx certbot python3-certbot-nginx docker.io docker-compose nodejs npm ufw fail2ban

