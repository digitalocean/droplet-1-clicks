#!/bin/bash

# Full path to the jupyter binary inside the conda environment
jupyter_path="/home/ubuntu/.conda/envs/jupyter/bin/jupyter"

# Function to check if JupyterLab is already running
is_jupyter_running() {
    jupyter_server_list=$($jupyter_path server list 2>/dev/null)
    if [[ $jupyter_server_list =~ "http://localhost:" ]]; then
        return 0  # JupyterLab is running
    fi
    return 1  # JupyterLab is not running
}

# Function to start JupyterLab server
start_jupyter() {
    if is_jupyter_running; then
        echo "JupyterLab is already running."
    else
        $jupyter_path lab --no-browser >> ~/notebook.log 2>&1 &
        echo "JupyterLab started." 
        echo "See the logs under ~/notebook.log."
        echo
        echo "Use 'notebook list' to view the URL."
        echo
        echo "Remember that you need to create a tunnel to access the notebook from your localhost." 
        echo "On another terminal, use ssh root@<ip> -L 8888:localhost:8888 to create the tunnel. Then you can access the notebook from your local browser."
        echo
    fi
}

# Function to stop JupyterLab server
stop_jupyter() {
    if is_jupyter_running; then
        read -p "Are you sure you want to stop JupyterLab? [y/N]: " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            $jupyter_path server stop
            echo "JupyterLab stopped."
        else
            echo "JupyterLab not stopped."
        fi
    else
        echo "JupyterLab is not running."
    fi
}

# Function to list running JupyterLab instances
list_jupyter() {
    $jupyter_path server list
}

# Display help message
print_help() {
    echo "Usage: $0 <start|stop|list>"
    echo ""
    echo "Options:"
    echo "  start    Start a new JupyterLab server instance"
    echo "  stop     Stop the currently running JupyterLab server"
    echo "  list     List running JupyterLab instances"
}

# Main script logic
case "$1" in
    "start")
        start_jupyter
        ;;
    "stop")
        stop_jupyter
        ;;
    "list")
        list_jupyter
        ;;
    *)
        print_help
        ;;
esac

