#!/bin/bash
set -e

duty=${1}
JUPYTER_PASSWORD=${2:-"root"}
PRIVATE_KEY=${3}
FILE_PATH=/local/host_list
PROJECT_KEY_PATH=/local/project_key
PROJECT_USER=project

# Basics

# Add new user
sudo addgroup $PROJECT_USER
sudo adduser --ingroup $PROJECT_USER --disabled-password --gecos "" $PROJECT_USER
echo $PROJECT_USER:password | sudo chpasswd
sudo usermod -aG sudo $PROJECT_USER
echo "$PROJECT_USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$PROJECT_USER

# System wide configs
sudo bash -c 'cat >> /etc/security/limits.conf <<-EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 131072
* hard nproc 131072

EOF'
chmod 777 /local/logs
chmod 666 -R /local/logs/*


# --------------------- Check if every host online ----------------------------
awk 'NR>1 {print $NF}' /etc/hosts | grep -v 'master' > $FILE_PATH
if [ "$duty" = "m" ]; then
    readarray -t hosts < $FILE_PATH
    while true; do
        echo "Checking if other hosts online"
        all_done=true
        for host in "${hosts[@]}"; do
            if nc -w 2 -z $host 22 2>/dev/null; then
                echo "$host ✓"
            else
                echo "$host ✗"
                all_done=false
            fi
        done
        

        if [ "$all_done" = true ] ; then
            break
        else
            echo "WAITING"
            sleep 5s
        fi
    done
fi
# -----------------------------------------------------------------------------





# Cerebro

# Project key
echo "${PRIVATE_KEY}" > $PROJECT_KEY_PATH
sudo chown $PROJECT_USER $PROJECT_KEY_PATH
sudo chmod 600 $PROJECT_KEY_PATH
echo 'eval `ssh-agent` &> /dev/null' | sudo tee -a /home/$PROJECT_USER/.bashrc
echo "ssh-add $PROJECT_KEY_PATH &> /dev/null" | sudo tee -a /home/$PROJECT_USER/.bashrc
sudo ssh-keygen -y -f $PROJECT_KEY_PATH | sudo tee -a /home/$PROJECT_USER/.ssh/authorized_keys
sudo chown -R $PROJECT_USER:$PROJECT_USER /home/$PROJECT_USER

# Setup cerebro
sudo -H -u $PROJECT_USER bash /local/repository/setup.sh ${duty}

# ------------------------- system settings -----------------------------------
git clone --single-branch --branch data_pipeline_test git@github.com:scnakandala/cerebro.git /local/cerebro
git clone https://github.com/scnakandala/cerebro.git
git clone https://github.com/greenplum-db/gporca.git /local/gporca
git clone https://github.com/greenplum-db/gp-xerces.git /local/gp-xerces
git clone https://github.com/apache/madlib.git /local/madlib
chmod 777 /local/gpdb_src /local/gporca /local/gp-xerces /local/madlib



# -----------------------------------------------------------------------------

# greenplum key
echo "${PRIVATE_KEY}" > $PROJECT_KEY_PATH
chown gpadmin $PROJECT_KEY_PATH
chmod 600 $PROJECT_KEY_PATH
ssh-keygen -y -f $PROJECT_KEY_PATH >> /home/gpadmin/.ssh/authorized_keys



# compile, install, and run gpdb, compile and install madlib
sudo -H -u  gpadmin bash /local/repository/install_gpdb.sh ${duty}



# -----------------------------------------------------------------------------
# Running Jupyter deamons
if [ "$duty" = "m" ]; then
  # python
  pip3 install --upgrade six
  pip3 install -r /local/repository/requirements_master.txt;
  # Jupyter extension configs
  sudo /usr/local/bin/jupyter contrib nbextension install --system ;
  sudo /usr/local/bin/jupyter nbextensions_configurator enable --system ;
  sudo /usr/local/bin/jupyter nbextension enable code_prettify/code_prettify --system ;
  sudo /usr/local/bin/jupyter nbextension enable execute_time/ExecuteTime --system ;
  sudo /usr/local/bin/jupyter nbextension enable collapsible_headings/main --system ;
  sudo /usr/local/bin/jupyter nbextension enable freeze/main --system ;
  sudo /usr/local/bin/jupyter nbextension enable spellchecker/main --system ;

  # Jupyter password
  mkdir -p ~/.jupyter;
  HASHED_PASSWORD=$(python3 -c "from notebook.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))");
  echo "c.NotebookApp.password = u'$HASHED_PASSWORD'" >~/.jupyter/jupyter_notebook_config.py;
  echo "c.NotebookApp.open_browser = False" >>~/.jupyter/jupyter_notebook_config.py;
    sudo nohup docker run --init -p 3000:3000 -v "/:/home/project:cached" theiaide/theia-python:next > /dev/null 2>&1 &
    sudo nohup jupyter notebook --no-browser --allow-root --ip 0.0.0.0 --notebook-dir=/ > /dev/null 2>&1 &
fi

# elif [ "$duty" = "s" ]; then
#   gpssh-exkeys -f hostlist_singlenode
# fi
echo "Bootstraping complete"


cp ~/.bashrc /local/.bashrc
touch /local/SUCCESS







