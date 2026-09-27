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
# Download Prometheus                                                                                             #
###################################################################################################################

cd /tmp
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.55.1/prometheus-3.15.0.linux-amd64.tar.gz

###################################################################################################################
# Extract the binaries and install the binaries.                                                                  #
###################################################################################################################

tar xvf prometheus-3.15.0.linux-amd64.tar.gz
sudo cp prometheus /usr/local/bin 
sudo promtool /usr/local/bin
sudo chown prometheus:prometheus /usr/bin/local/prometheus
sudo chown prometheus:prometheus /usr/bin/local/promtool

###################################################################################################################



curl -o prometheus-3.15.0.linux-amd64.tar.gz



