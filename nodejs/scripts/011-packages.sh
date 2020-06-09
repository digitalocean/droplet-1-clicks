#!/bin/sh

sudo npm install pm2@latest -g --no-optional

pm2 start /var/www/html/hello.js
pm2 startup systemd
pm2 save
