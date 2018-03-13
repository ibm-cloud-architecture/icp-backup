#!/bin/bash

# Install node.js  
# Ubuntu specific
# See: https://nodejs.org/en/download/package-manager/#debian-and-ubuntu-based-linux-distributions
# couchbackup needs at least node v6+
# Need to run as root or use sudo

curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash -
sudo apt-get install -y nodejs


