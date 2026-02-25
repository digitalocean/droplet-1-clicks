# Droplet 1-Click Image - Conda and Jupyter

## Description

This Droplet 1-Click Image is pre-installed with Conda and Jupyter, providing you with a streamlined environment for data science and machine learning tasks. Conda allows you to easily manage software packages and create isolated environments, while Jupyter provides a web-based interface for interactive coding and data exploration. With this image, you can quickly set up a powerful data science environment without the hassle of manual installation.

## Before You Deploy

Before deploying this Droplet, consider the following guidance to ensure you choose the right configuration for your needs:

- Droplet Size: Depending on your data processing requirements, select a Droplet size that offers sufficient CPU, memory, and storage resources. Consider the complexity and scale of your projects when making this decision.

- Volume: If you anticipate working with large datasets or require additional storage, it is recommended to attach a Volume to your Droplet. This will provide you with the necessary space to store and access your data conveniently.

## Software Versions

This Droplet comes with the following software versions pre-installed:

- Conda: [Latest version of Conda](https://docs.conda.io/)
- Jupyter: [Latest version of Jupyter](https://jupyter.org/)

## Getting Started with Jupyter

After deploying the Jupyter Droplet, follow these steps to get started:

1. SSH into your Droplet:
   - Use your preferred SSH client to connect to your Droplet.

2. Switch to the Ubuntu user:
   - Once connected, switch to the Ubuntu user by running the following command:
     ```
     su - ubuntu
     ```

3. Accessing the Jupyter Notebook:
   - You can access the Jupyter Notebook by starting it manually or using the provided `notebook.sh` script.
   - To manually start Jupyter Notebook, run the following command:
     ```
     conda activate jupyter
     jupyter notebook
     ```
   - Alternatively, you can use the `notebook.sh` script by executing:
     ```
     ./notebook.sh
     ```
   - The script will handle starting the JupyterLab instance for you.

4. Creating and Managing Conda Environments:
   - Once you have accessed the Jupyter Notebook, you can use Conda to create isolated environments for your projects.
   - To create a new Conda environment, use the following command:
     ```
     conda create --name myenv
     ```
   - Activate the environment by running:
     ```
     conda activate myenv
     ```
   - Install required packages and libraries within the environment using Conda or pip.

For more detailed instructions and tips on using Conda and Jupyter, please refer to the Conda documentation: [https://docs.conda.io/](https://docs.conda.io/)

## Sample Application

Source: [Link](https://github.com/bes-dev/stable_diffusion.openvino)

A sample application included with this Droplet is the "stable diffusion 1.5" model. To run this application, ensure that your Droplet meets the following specifications:

- CPU: At least 16 cores
- RAM: At least 32GB
- Droplet Type: Premium CPU-optimized (Xeon series 3)

Please note that running the "stable diffusion 1.5" model can be computationally intensive. In our tests, it takes approximately 1 minute to generate a single image. Commands:

```
su - ubuntu # if you have not switched to ubuntu user already
cd examples/stable_diffusion.openvino/
conda activate stable-diffusion-1.5
python demo.py --prompt "Beautiful lake, sunset, and a mountain"
```

The output is stored in output.png file. If you have connected to Jupyter notebook, you should be able to view the file in the notebook itself.

## Sample Applications by Intel

Source: [Link](https://github.com/openvinotoolkit/openvino_notebooks.git)

Intel maintains a number of sample applications that you can try out and customize. These applications have been optimized to work on Intel hardware. Note that some of these may need a GPU and will not work on CPU.

A simple one to try out is [distilbert-sequence-classification](https://github.com/openvinotoolkit/openvino_notebooks/tree/main/notebooks/229-distilbert-sequence-classification) for sentiment analysis.

---

For additional information and support, please visit the [DigitalOcean Documentation](https://www.digitalocean.com/docs/) and [Community Tutorials](https://www.digitalocean.com/community/tutorials/).
