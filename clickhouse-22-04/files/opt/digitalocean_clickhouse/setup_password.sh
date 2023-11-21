#!/bin/bash

PASSWORD=$(base64 < /dev/urandom | head -c8)
HASHED=$(echo -n "$PASSWORD" | sha256sum | tr -d '-')
HASHED=$(echo -n "$HASHED" | xargs)

echo "ClickHouse is now installed and configure. Enjoy it!"
echo ""
echo "----------------------------------------------------------------------------"
echo "Your default password is \"$PASSWORD\". To update it you can run:"
echo "PASSWORD=\$(base64 < /dev/urandom | head -c8); echo \"\$PASSWORD\"; echo -n \"\$PASSWORD\" | sha256sum | tr -d '-'"
echo "First line is the new password, second is the hashed password can be used in clickhouse conf file."
echo "Update section 'password_sha256_hex' value with generated hash in the file '/etc/clickhouse-server/users.d/default-password.xml'"
echo "----------------------------------------------------------------------------"

cp -f /etc/skel/.bashrc /root/.bashrc

sed -e "s/<password_sha256_hex>.*<\/password_sha256_hex>/<password_sha256_hex>${HASHED}<\/password_sha256_hex>/" \
    -i /etc/clickhouse-server/users.d/default-password.xml

sudo service clickhouse-server start
