#!/bin/bash

set -e

sudo adduser --disabled-password --gecos "" ubuntu
sudo usermod -aG sudo ubuntu
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

sudo -u ubuntu bash <<EOF
echo "Now installing conda"
cd ~
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
sudo bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda

/opt/conda/bin/conda init 
sudo /opt/conda/bin/conda update -y -n base -c defaults conda
sudo /opt/conda/bin/conda install -y -c conda-forge conda-bash-completion

/opt/conda/bin/conda init 
\rm Miniconda3*
EOF

# Change permissions of files copies by file module
mv ~/* /home/ubuntu/
sudo chown -R ubuntu:ubuntu /home/ubuntu/*
sudo chmod +x /home/ubuntu/notebook.sh

