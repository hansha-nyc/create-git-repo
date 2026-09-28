# Prometheus monitoring tool.
# Antman - Milkyway

#!/bin/bash

sudo apt update 

###################################################################################################################
# Create prometheus user and directories for prometheus.                                                          #
###################################################################################################################

sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

###################################################################################################################
# Download Prometheus using curl                                                                                             #
###################################################################################################################

cd /tmp
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.55.1/prometheus-3.15.0.linux-amd64.tar.gz

###################################################################################################################
# Extract the binaries and install the binaries.                                                                  #
###################################################################################################################

tar xvf prometheus-3.15.0.linux-amd64.tar.gz
cd prometheus-3.15.0.linux-amd64

sudo cp prometheus /usr/local/bin 
sudo promtool /usr/local/bin
sudo chown prometheus:prometheus /usr/bin/local/prometheus
sudo chown prometheus:prometheus /usr/bin/local/promtool

###################################################################################################################
# Copy the config and console files                                                                               # 
###################################################################################################################

sudo cp -r consoles /etc/prometheus 
sudo cp -r console_libraries /etc/prometheus
sudo cp prometheus.yml /etc/prometheus/prometheus.yml

sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus

###################################################################################################################
# Creation of a systemd service                                                                                   #
###################################################################################################################

sudo tee /etc /systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file /etc/prometheus/prometheus.yml
  --storage.tsdb.path /var/lib/promtheus/ \
  --web.console.templates=/etc/prometheus/consoles/ \
  --web.console.libraries=/etc/prometheus/console_libraries

  [Install]
  WantedBy=multi-user.target
  EOF


  ####################################################################################################################
  # Start prometheus service and enable the service                                                                   #
  ####################################################################################################################

  sudo systemctl daemon-reload
  sudo systemctl start prometheus 
  sudo systemctl enable prometheus
  sudo systemctl status prometheus

  ####################################################################################################################
  # Check the status of the prometheus service                                                                        #
  ####################################################################################################################   
  
  curl http://localhost:9090/
                                                                     #




