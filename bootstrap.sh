#!/bin/bash
set -e

duty=${1}
JUPYTER_PASSWORD=${2:-"root"}
PRIVATE_KEY=${3}
SETUP_EXP=${4:-"false"}
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
sudo chmod 777 -R /local
sudo chmod 666 -R /local/logs/*


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


# Setup cerebro
sudo -H -u $PROJECT_USER bash /local/repository/setup.sh ${duty} ${PROJECT_KEY_PATH}

# -----------------------------------------------------------------------------
# Running Jupyter deamons
if [ "$duty" = "m" ]; then
  # python
  pip install --upgrade six
  pip install -r /local/repository/requirements_master.txt;
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
    sudo -u $PROJECT_USER nohup docker run --init -p 3000:3000 -v "/:/home/project:cached" theiaide/theia-python:next > /dev/null 2>&1 &
    sudo -u $PROJECT_USER nohup jupyter notebook --no-browser --allow-root --ip 0.0.0.0 --notebook-dir=/ > /dev/null 2>&1 &
fi

# elif [ "$duty" = "s" ]; then
#   gpssh-exkeys -f hostlist_singlenode
# fi
echo "Bootstraping complete"


cp ~/.bashrc /local/.bashrc
touch /local/SUCCESS








