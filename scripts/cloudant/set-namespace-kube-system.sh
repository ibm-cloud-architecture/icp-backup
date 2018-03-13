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
#   Switch the preferred namespace to kube-system
#
# Assumptions:
#  1. A kube context has been established.
#  2. Logged in as admin. 
#  3. ICP cluster name is default, mycluster
#
# "kubectl config view", can be used to confirm namespace change.
#

kubectl config set-context mycluster.icp-context --user admin --namespace=kube-system

