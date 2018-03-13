#!/bin/bash

# Switch the preferred namespace to kube-system
#
# Assumptions:
#  1. A kube context has been established.
#  2. Logged in as admin. 
#  3. ICP cluster name is default, mycluster

# "kubectl config view", can be used to confirm namespace change.


kubectl config set-context mycluster.icp-context --user admin --namespace=kube-system

