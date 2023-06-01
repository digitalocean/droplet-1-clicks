-  Start by checking if the conda command is working. If not, run the following command:
  /opt/conda/bin/conda init
  
  This command will set up the necessary configuration in the ~/.bashrc file. You may need to source ~/.bashrc or exit and run su - ubuntu again.

- Jupyter Notebook is installed under the jupyter environment. You can manually start it yourself or use the ~/notebook.sh script provided. The script is self-explanatory.
  - If you want to run Jupyter Notebook instead of JupyterLab, you can manually enter the Jupyter virtual environment by running conda activate jupyter.
  - The ./notebook.sh script supports running only one JupyterLab instance, which is suitable for most use cases. If you need multiple instances, you'll have to run them up manually by providing port number to have different instances listening on different ports.

- Here's an example you can try out-of-the-box:
  cd ~/examples/stable_diffusion.openvino

  Remember to switch to the stable-diffusion-1.5 environment by executing 'conda activate stable-diffusion-1.5'.

- If you are new to Conda, you can refer to the Conda cheat sheet for a list of commands:
https://docs.conda.io/projects/conda/en/4.6.0/_downloads/52a95608c49671267e40c689e0bc00ca/conda-cheatsheet.pdf

- When running Jupyter Notebook in a separate environment (let's say venv1) from your actual application environment (let's say venv2), you need to add the venv2 kernel (path to Conda packages) to Jupyter Notebook. Run the following commands in venv2, and you will be able to see the venv2 kernel in Jupyter Notebook:

yes | pip install ipykernel
python -m ipykernel install --user --name <venv2> --display-name "<venv2>"

- To inspect the source Packer files of this image, go to https://github.com/digitalocean/droplet-1-clicks and navigate to the jupyter-conda folder.

- The examples and virtual environments are taking 9GB of space. They are not taking up compute, unless you are running things. To clean up, it is just 3 command. Review the file 'Save-9GB-by-deleting-examples.txt'
