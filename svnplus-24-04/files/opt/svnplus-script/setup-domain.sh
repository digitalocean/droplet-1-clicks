#!/bin/bash
echo "Enter the domain name for your new SVNPlus site."
echo "(ex. example.org or test.example.org) do not include www or http/s"
echo "--------------------------------------------------"

while true; do
    read -p "Domain/Subdomain name: " dom
    if [ -z "$dom" ];then
        echo "Please provide a valid domain or subdomain name to continue"
    else
        break;
    fi
done

mv /etc/nginx/sites-available/nginx-repo-forward.conf /etc/nginx/sites-available/$dom.conf
sed -i "s/\%DOMAIN%/$dom/g"  /etc/nginx/sites-available/$dom.conf
ln -s /etc/nginx/sites-available/$dom.conf /etc/nginx/sites-enabled/

service nginx restart

echo -en "\n\n\n"
while true; do
    read -p "Do you want to use LetsEncrypt (certbot) to configure SSL(https) for your new site? (Y/n): " yn
    yn=${yn:-y}
    case $yn in
        [Yy]* ) certbot --nginx; echo "SVNPlus has been enabled at https://$dom You can use this URL to access your repositories.";break;;
        [Nn]* ) echo "Skipping LetsEncrypt certificate generation";break;;
        * ) echo "Please answer y or n.";;
    esac
done
