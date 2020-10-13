#!/bin/sh

# Install rvm
apt-add-repository -y ppa:rael-gc/rvm
apt update
apt install rvm

useradd --home-dir /home/rails --shell /bin/bash --create-home --user-group rails --groups rvm

cat >> /home/rails/.bashrc << EOF
source /etc/profile.d/rvm.sh
EOF

echo "## Install  Ruby"
su - rails -c "rvm install ruby-${ruby_version} --default"

echo "## Install Rails"
su - rails -c "gem install rails -v ${rails_version}"

echo "## Install Puma"
su - rails -c "gem install puma -v ${puma_version}"

echo "## Install pg"
su - rails -c "gem install pg -v ${pg_version}"

echo "## Install sassc"
su - rails -c "gem install sassc -v ${sassc_version} -- --disable-march-tune-native"

echo "## Create rails project"
su - rails -c "rails new example -d postgresql"

