#!/bin/sh

# Get the latest Anaconda version
anaconda_filename=$(curl -s https://repo.anaconda.com/archive/ | grep -o 'Anaconda3-[0-9]\+\.[0-9]\+-[0-9]\+-Linux-x86_64\.sh' | sort -V | tail -1)
anaconda_installer_url="https://repo.anaconda.com/archive/${anaconda_filename}"
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
sudo -u anaconda /home/anaconda/anaconda3/bin/conda config --set always_yes true
sudo -u anaconda /home/anaconda/anaconda3/bin/conda config --set auto_update_conda false
sudo -u anaconda /home/anaconda/anaconda3/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
sudo -u anaconda /home/anaconda/anaconda3/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
sudo -u anaconda /home/anaconda/anaconda3/bin/conda tos accept --channel conda-forge
sudo /home/anaconda/anaconda3/bin/conda update -y -n base -c defaults conda
sudo /home/anaconda/anaconda3/bin/conda install -y -c conda-forge conda-bash-completion

# Change permissions of files copies by file module
sudo chown -R anaconda: /etc/jupyter/*
