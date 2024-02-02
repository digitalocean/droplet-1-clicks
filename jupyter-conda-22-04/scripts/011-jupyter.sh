#!/bin/bash

set -e

# JUPYTER
sudo -u ubuntu bash <<EOF
echo "Now installing jupyter environment"

cd ~
source /opt/conda/etc/profile.d/conda.sh

conda create -n jupyter python=3.11 --yes
conda activate jupyter

yes| pip install  pip --upgrade 
yes| pip install  -r jupyter/requirements.txt --upgrade

conda deactivate
EOF

# Stable Diffusion 1.5
sudo -u ubuntu bash <<EOF
echo "Now installing stable diffusion 1.5 environment"

mkdir /home/ubuntu/examples
cd /home/ubuntu/examples

git clone https://github.com/bes-dev/stable_diffusion.openvino.git
cd /home/ubuntu/examples/stable_diffusion.openvino
source /opt/conda/etc/profile.d/conda.sh

conda create -n stable-diffusion-1.5 python=3.9 --yes
conda activate stable-diffusion-1.5

yes| pip install  pip --upgrade 
yes| pip install openvino-dev[onnx,pytorch]==2022.3.0
yes| pip install -r requirements.txt
yes| pip install ipykernel

python -m ipykernel install --user --name stable-diffusion-1.5 --display-name "Stable Diffusion 1.5"

conda deactivate
EOF

# Install Intel Openvino Tutorials
sudo -u ubuntu bash <<EOF
echo "Now installing Intel Openvino notebooks and environment"

cd /home/ubuntu/examples
git clone --depth=1 https://github.com/openvinotoolkit/openvino_notebooks.git
cd openvino_notebooks
sed -i 's/^jupyterlab/#jupyterlab/; s/^ipywidgets/#ipywidgets/; s/^ipykernel/#ipykernel/; s/^ipython/#ipython/' requirements.txt

source /opt/conda/etc/profile.d/conda.sh

conda create -n openvino_notebooks python=3.10 --yes
conda activate openvino_notebooks

yes| python -m pip install --upgrade pip 
yes| pip install wheel setuptools
yes| pip install -r requirements.txt
yes| pip install ipykernel

python -m ipykernel install --user --name openvino_notebooks --display-name “Openvino-Notebooks”

conda deactivate

EOF

