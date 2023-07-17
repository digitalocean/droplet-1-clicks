#!/bin/bash

echo "This script will setup Supabase"
echo "--------------------------------------------------"
echo "This setup requires a domain name.  If you do not have one yet, you may"
echo "cancel this setup, press Ctrl+C.  This script will run again on your next login"
echo "--------------------------------------------------"
echo "Enter the domain name for your new Supabase site."
echo "(ex. example.org or test.example.org) do not include www or http/s"
echo "--------------------------------------------------"

a=0
while [ $a -eq 0 ]
do
 read -p "Domain/Subdomain name: " dom
 if [ -z "$dom" ]
 then
  a=0
  echo "Please provide a valid domain or subdomain name to continue or press Ctrl+C to cancel"
 else
  a=1
fi
done

while [ -z $email ]
do
    echo -en "\n"
    read -p "Your Email Address: " email
done

service nginx stop

sudo certbot certonly --standalone --agree-tos --no-eff-email --staple-ocsp --preferred-challenges http -m $email -d $dom
if [ $? -eq 0 ]
then
    echo "certbot successfully created a certificate"
else
    echo "certbot failed"
    exit 1
fi

sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
if [ $? -eq 0 ]
then
    echo "dhparam successed"
else
    echo "dhparam failed"
    exit 1
fi

sudo mkdir -p /var/lib/letsencrypt

cat > /etc/cron.daily/certbot-renew <<EOM
#!/bin/sh
certbot renew --cert-name $dom --webroot -w /var/lib/letsencrypt/ --post-hook "systemctl reload nginx" 
EOM
sudo chmod +x /etc/cron.daily/certbot-renew

sed -i "s/supabase.example.com/$dom/g" /opt/digitalocean/supabase_ssl
rm -rf /etc/nginx/sites-available/supabase
cp -rf /opt/digitalocean/supabase_ssl /etc/nginx/sites-available/supabase

service nginx start
