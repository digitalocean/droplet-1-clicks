#!/bin/sh

anaconda_version=${ANACONDA_VERSION}
anaconda_installer_url="https://repo.anaconda.com/archive/Anaconda3-${anaconda_version}-Linux-x86_64.sh"
anaconda_script=/tmp/anaconda.sh
home_dir=/home/digitalocean

curl $anaconda_installer_url --output $anaconda_script

# Create the digitalocean user
useradd --home-dir $home_dir \
        --shell /bin/bash \
        --create-home \
        --system \
        digitalocean

passwd -l digitalocean

# Setup the home directory
chown -R digitalocean: $home_dir

bash $anaconda_script -b -p $home_dir/anaconda3

/home/digitalocean/anaconda3/bin/conda init
sudo /home/digitalocean/anaconda3/bin/conda update -y -n base -c defaults conda
sudo /home/digitalocean/anaconda3/bin/conda install -y -c conda-forge conda-bash-completion
