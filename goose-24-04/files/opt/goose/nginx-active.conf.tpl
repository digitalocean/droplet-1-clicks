# Web console: HTTPS + Basic Auth -> ttyd (Goose 1-Click)
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

    ssl_certificate __SSL_CERT__;
    ssl_certificate_key __SSL_KEY__;
    ssl_protocols TLSv1.2 TLSv1.3;

    auth_basic "Goose web console";
    auth_basic_user_file /etc/nginx/.goose-ttyd.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:7681;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
