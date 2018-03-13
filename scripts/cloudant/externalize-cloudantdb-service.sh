#!/bin/bash
#
# Use the CloudantDBNodePort.yaml from the icp-backup git repo 
# to externalize the ICP cloudantdb service.
#
# Assumptions:
#   1. The icp-backup git repo was cloned in the current directory
#   2. kubectl has been installed.
#   3. User has a current kube context configured.  (See ICPClientConfig.sh) 
#
if [ ! -f ./icp-backup/scripts/CloudantDBNodePort.yaml ]; then
  echo "ERROR: ./icp-backup/scripts/CloudantDBNodePort.yaml does not exist."
  echo "Clone the icp-backup git repo before running this script."
  exit 1
fi

exists=$(kubectl get svc --namespace=kube-system | grep cloudantdb-ext)
if [ -z "$exists" ]; then
  kubectl --namespace=kube-system apply -f ./icp-backup/scripts/CloudantDBNodePort.yaml
else
  echo "The cloudantdb-ext service is already defined:"
  echo "$exists"
fi


