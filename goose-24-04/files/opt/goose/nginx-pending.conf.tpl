# Replaced after first SSH login with the active console config (see /opt/goose/)
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name __DROPLET_IP__;
    root /var/www/html;

    location /.well-known/acme-challenge/ {
        try_files $uri =404;
    }

    location / {
        return 302 https://$host$request_uri;
    }
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name __DROPLET_IP__;

    ssl_certificate /etc/ssl/goose/selfsigned.crt;
    ssl_certificate_key /etc/ssl/goose/selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        default_type text/plain;
        return 503 "Complete first-time setup: SSH to this Droplet as root. A short wizard will set your web console password, install Goose, and obtain a Let's Encrypt certificate.\n";
    }
}
