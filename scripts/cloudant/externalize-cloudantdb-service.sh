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
#   Use the cloudant-db-node-port.yaml from the icp-backup git repo
#   to externalize the ICP cloudantdb service.
#
# Pre-reqs:
#   1. Clone
#   2. kubectl is needed to apply the yaml to externalize the service.
#
# Assumptions:
#   1. User has a current kube context configured.  (See icp-client-config.sh)
#   2. The default place to run this script from the icp-backup/scripts directory.
#
#
################################################################################
function usage {
  echo ""
  echo "Usage: externalize-cloudantdb-service.sh [options]"
  echo "   --yaml-path <path>   - (optional) Path to yaml file that externalizes the cloudantdb service."
  echo "                                     Defaults to cloudant-db-node-port.yaml in the current directory."
  echo ""
  echo "   --help|-h                        - emit this usage information"
  echo ""
  echo " - and -- are accepted as keyword argument indicators"
  echo ""
  echo "Sample invocations:"
  echo "  ./externalize-cloudantdb-service.sh"
  echo "  ./externalize-cloudantdb-service.sh --yaml-path ../../resources/cloudant-db-node-port.yaml"
  echo ""
}

# The info() function is used to emit log messages.
# It is assumed that SCRIPT is set in the caller.
function info {
  local lineno=$1; shift
  local ts=$(date +[%Y/%m/%d-%T])
  echo "$ts $SCRIPT($lineno) $*"
}

############ "Main" starts here
SCRIPT=${0##*/}

info $LINENO "BEGIN $SCRIPT"

yaml_path=""

# process the input args
# For keyword-value arguments the arg gets the keyword and
# the case statement assigns the value to a script variable.
# If any "switch" args are added to the command line args,
# then it wouldn't need a shift after processing the switch
# keyword.  The script variable for a switch argument would
# be initialized to "false" or the empty string and if the
# switch is provided on the command line it would be assigned
# "true".
#
while (( $# > 0 )); do
  arg=$1
  case $arg in
    -h|--help ) usage; exit 0
                ;;

    -yaml-path|--yaml-path )  yaml_path=$2; shift
                ;;

    * ) usage;
        info $LINENO "ERROR: Unknown option: $arg in command line."
        exit 1
        ;;
  esac
  # shift to next key-value pair
  shift
done

if [ -z "$yaml_path" ]; then
  yaml_path=cloudant-db-node-port.yaml
fi

if [ ! -f "$yaml_path" ]; then
  info $LINENO "ERROR: $yaml_path does not exist."
  exit 1
fi

exists=$(kubectl get svc --namespace=kube-system | grep cloudantdb-ext)
if [ -z "$exists" ]; then
  kubectl --namespace=kube-system apply -f "$yaml_path"
else
  info $LINENO "The cloudantdb-ext service is already defined:"
  info $LINENO "$exists"
fi

info $LINENO "END $SCRIPT"
