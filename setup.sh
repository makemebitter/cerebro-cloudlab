#!/bin/bash
set -e
duty=${1}
PROJECT_KEY_PATH=${2}
echo 'eval `ssh-agent` &> /dev/null' | sudo tee -a ~/.bashrc
echo "ssh-add $PROJECT_KEY_PATH &> /dev/null" | sudo tee -a ~/.bashrc
sudo ssh-keygen -y -f $PROJECT_KEY_PATH | sudo tee -a ~/.ssh/authorized_keys
sudo chown -R $PROJECT_USER:$PROJECT_USER /home/$PROJECT_USER
git clone --single-branch --branch data_pipeline_test git@github.com:scnakandala/cerebro.git /local/cerebro
