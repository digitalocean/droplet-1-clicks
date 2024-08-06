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

passwd -l anaconda

# Setup the home directory
chown -R anaconda: $home_dir

bash $anaconda_script -b -p $home_dir/anaconda3

/home/anaconda/anaconda3/bin/conda init
sudo /home/anaconda/anaconda3/bin/conda update -y -n base -c defaults conda
sudo /home/anaconda/anaconda3/bin/conda install -y -c conda-forge conda-bash-completion

# Change permissions of files copies by file module
sudo chown -R anaconda: /etc/jupyter/*
