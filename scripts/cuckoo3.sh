#!/bin/bash

# Update package repositories
sudo apt update

# Install Python 2 and dependencies
sudo apt install -y python2 python-pip python-dev libffi-dev libssl-dev virtualbox virtualbox-guest-additions-iso tcpdump apparmor-utils

# Install Cuckoo Sandbox dependencies
sudo apt install -y mongodb postgresql libpq-dev

# Install Python packages using Python 2
sudo pip2 install -U pip setuptools
sudo pip2 install -U cuckoo

# Configure and initialize Cuckoo
cuckoo init
cuckoo community --force
cuckoo web --host 0.0.0.0 --port 8080

# Start Cuckoo services
sudo cuckoo -d

# Set up virtualization
sudo adduser $USER vboxusers
sudo modprobe vboxdrv
sudo modprobe vboxnetflt

echo "Cuckoo Sandbox installation complete. You can access the web interface at http://localhost:8080."