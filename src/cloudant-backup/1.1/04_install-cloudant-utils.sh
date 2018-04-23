#!/bin/bash

# Install couchbackup (and restore) utility
# Install couchdb-cli (coucher) command line utility
#
# Assumes npm is already installed (with nodejs).
# 
# For details on couchbackup:
# See https://www.npmjs.com/package/@cloudant/couchbackup
# 
# Minimum required nodejs 6.13.0 
# Minimum required CloudantDB 2.0.0
#
# For detaions on couchdb-cli:
# See https://www.npmjs.com/package/couchdb-cli
#


sudo npm install -g @cloudant/couchbackup

sudo npm install -g couchdb-cli 
