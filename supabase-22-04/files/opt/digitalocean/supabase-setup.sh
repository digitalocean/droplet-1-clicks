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
  echo "Please provide a valid domain or subdomain name to continue to press Ctrl+C to cancel"
 else
  a=1
fi
done

while [ -z $email ]
do
    echo -en "\n"
    read -p "Your Email Address: " email
done

sudo certbot certonly --standalone --agree-tos --no-eff-email --staple-ocsp --preferred-challenges http -m $email -d $dom
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
sudo mkdir -p /var/lib/letsencrypt

cat > /etc/cron.daily/certbot-renew <<EOM
#!/bin/sh
certbot renew --cert-name supabase.example.com --webroot -w /var/lib/letsencrypt/ --post-hook "systemctl reload nginx" 
EOM
sudo chmod +x /etc/cron.daily/certbot-renew

sed -i "s/supabase.example.com/$dom/g" /opt/digitalocean/supabase_ssl
rm -rf /etc/nginx/sites-available/supabase
cp -i /opt/digitalocean/supabase_ssl /etc/nginx/sites-available/supabase

systemctl restart nginx
