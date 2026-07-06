#!/bin/sh

anaconda_version=${ANACONDA_VERSION}
anaconda_installer_url="https://repo.anaconda.com/archive/Anaconda3-${anaconda_version}-Linux-x86_64.sh"
anaconda_script=/tmp/anaconda.sh
home_dir=/home/anaconda

curl $anaconda_installer_url --output $anaconda_script

# Create the anaconda user
useradd --home-dir $home_dir \
        --shell /bin/bash \
        --create-home \
        --system \
        anaconda

# Setup the home directory
chown -R anaconda: $home_dir

bash $anaconda_script -b -p $home_dir/anaconda3
