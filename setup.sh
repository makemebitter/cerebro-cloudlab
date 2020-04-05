#!/bin/bash
set -e
duty=${1}
PROJECT_KEY_PATH=${2}
SETUP_EXP=${3:-"false"}

# Permissions, keys
mkdir ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'eval `ssh-agent` &> /dev/null' | sudo tee -a ~/.bashrc
echo "ssh-add $PROJECT_KEY_PATH &> /dev/null" | sudo tee -a ~/.bashrc
echo 'export WORKER_NAME=$(cat /proc/sys/kernel/hostname | cut -d'.' -f1)' | sudo tee -a ~/.bashrc
echo 'export WORKER_NUMBER=$(sed -n -e 's/^.*worker//p' <<<"$WORKER_NAME")' | sudo tee -a ~/.bashrc

sudo ssh-keygen -y -f $PROJECT_KEY_PATH | sudo tee -a ~/.ssh/authorized_keys
sudo chown -R $PROJECT_USER:$PROJECT_USER /home/$PROJECT_USER
# Allow OpenSSH to talk to nodes without asking for confirmation
sudo sh -c 'cat /etc/ssh/ssh_config | grep -v StrictHostKeyChecking > /etc/ssh/ssh_config.new' && \
    sudo sh -c 'echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config.new' && \
    sudo mv /etc/ssh/ssh_config.new /etc/ssh/ssh_config

source ~/.bashrc
ssh-agent bash -c "ssh-add $PROJECT_KEY_PATH; git clone --single-branch --branch data_pipeline_test git@github.com:scnakandala/cerebro.git /local/cerebro"



cd /local/cerebro
bash cloudlab_setup_cpu.sh ${duty}

if [ $SETUP_EXP = 'true' ]; then
    bash /local/cerebro/exps/setup.sh ${duty}
fi