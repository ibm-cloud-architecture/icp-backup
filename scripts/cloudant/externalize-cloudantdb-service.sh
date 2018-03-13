#!/bin/bash
#
# Licensed Material - Property of IBM
# 5724-I63, 5724-H88, (C) Copyright IBM Corp. 2018 - All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#
# DISCLAIMER:
# The following source code is sample code created by IBM Corporation.
# This sample code is provided to you solely for the purpose of assisting you
# in the  use of  the product. The code is provided 'AS IS', without warranty or
# condition of any kind. IBM shall not be liable for any damages arising out of 
# your use of the sample code, even if IBM has been advised of the possibility 
# of such damages.
#
# DESCRIPTION:
#   Use the CloudantDBNodePort.yaml from the icp-backup git repo 
#   to externalize the ICP cloudantdb service.
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


