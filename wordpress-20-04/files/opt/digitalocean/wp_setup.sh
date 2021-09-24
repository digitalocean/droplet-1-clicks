#!/bin/bash
#
# WordPress activation script
#
# This script will configure Apache with the domain
# provided by the user and offer the option to set up
# LetsEncrypt as well.

# Enable WordPress on first login
if [[ -d /var/www/wordpress ]]
then
  mv /var/www/html /var/www/html.old
  mv /var/www/wordpress /var/www/html
fi
chown -Rf www-data:www-data /var/www/html

# if applicable, configure wordpress to use mysql dbaas
if [ -f "/root/.digitalocean_dbaas_credentials" ]; then
  # grab all the data from the password file
  username=$(sed -n "s/^db_username=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  password=$(sed -n "s/^db_password=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  host=$(sed -n "s/^db_host=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  port=$(sed -n "s/^db_port=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)
  database=$(sed -n "s/^db_database=\"\(.*\)\"$/\1/p" /root/.digitalocean_dbaas_credentials)

  # update the wp-config.php with stored credentials
  sed -i "s/'DB_USER', '.*'/'DB_USER', '$username'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_NAME', '.*'/'DB_NAME', '$database'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_PASSWORD', '.*'/'DB_PASSWORD', '$password'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_HOST', '.*'/'DB_HOST', '$host:$port'/g" /var/www/html/wp-config.php;

  # add required SSL flag
  cat >> /var/www/html/wp-config.php <<EOM
/** Connect to MySQL cluster over SSL **/
define( 'MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL );
EOM

  # wait for db to become available
  echo -e "\nWaiting for your database to become available (this may take a few minutes)"
  while ! mysqladmin ping -h "$host" -P "$port" --silent; do
      printf .
      sleep 2
  done
  echo -e "\nDatabase available!\n"

  # cleanup
  unset username password host port database
  rm -f /root/.digitalocean_dbaas_credentials

  # disable the local MySQL instance
  systemctl stop mysql.service
  systemctl disable mysql.service
fi

echo "This script will copy the WordPress installation into"
echo "Your web root and move the existing one to /var/www/html.old"
echo "--------------------------------------------------"
echo "This setup requires a domain name.  If you do not have one yet, you may"
echo "cancel this setup, press Ctrl+C.  This script will run again on your next login"
echo "--------------------------------------------------"
echo "Enter the domain name for your new WordPress site."
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
sed -i "s/\$domain/$dom/g"  /etc/apache2/sites-enabled/000-default.conf
a2enconf block-xmlrpc

service apache2 restart

echo -en "Now we will create your new admin user account for WordPress."

function wordpress_admin_account(){

  while [ -z $email ]
  do
    echo -en "\n"
    read -p "Your Email Address: " email
  done

  while [ -z $username ]
  do
    echo -en "\n"
    read -p  "Username: " username
  done

  while [ -z $pass ]
  do
    echo -en "\n"
    read -s -p "Password: " pass
    echo -en "\n"
  done

  while [ -z "$title" ]
  do
    echo -en "\n"
    read -p "Blog Title: " title
  done
}

wordpress_admin_account

while true
do
    echo -en "\n"
    read -p "Is the information correct? [Y/n] " confirmation
    confirmation=${confirmation,,}
    if [[ "${confirmation}" =~ ^(yes|y)$ ]] || [ -z $confirmation ]
    then
      break
    else
      unset email username pass title confirmation
      wordpress_admin_account
    fi
done

echo -en "\n\n\n"
echo "Next, you have the option of configuring LetsEncrypt to secure your new site.  Before doing this, be sure that you have pointed your domain or subdomain to this server's IP address.  You can also run LetsEncrypt certbot later with the command 'certbot --apache'"
echo -en "\n\n\n"
 read -p "Would you like to use LetsEncrypt (certbot) to configure SSL(https) for your new site? (y/n): " yn
    case $yn in
        [Yy]* ) certbot --apache; echo "WordPress has been enabled at https://$dom  Please open this URL in a browser to complete the setup of your site.";break;;
        [Nn]* ) echo "Skipping LetsEncrypt certificate generation";break;;
        * ) echo "Please answer y or n.";;
    esac

echo "Finalizing installation..."
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/bin/wp
chmod +x /usr/bin/wp

echo -en "Completing the configuration of WordPress."
wp core install --allow-root --path="/var/www/html" --title="$title" --url="$dom" --admin_email="$email"  --admin_password="$pass" --admin_user="$username"

wp plugin install wp-fail2ban --allow-root --path="/var/www/html"
wp plugin activate wp-fail2ban --allow-root --path="/var/www/html"
chown -Rf www-data.www-data /var/www/
cp /etc/skel/.bashrc /root

echo "Installation complete. Access your new WordPress site in a browser to continue."
