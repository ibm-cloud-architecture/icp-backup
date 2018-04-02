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
#   Create one or more ICP Cloudant databases.
#
# Pre-reqs:
#    kubectl is needed to interact with the ICP cluster.
#    jq is needed to do JSON parsing.
#    coucher-cli is used to create databases.
#
# INPUTS:
#   1. Kubernetes service host name, host name (FQDN) or IP address of the
#      Cloudant DB server. (optional) Defaults to cloudantdb.kube-system.
#      If running outside a container, this needs to be one of the ICP master
#      nodes where the Cloudant database service is running.
#
#   2. One or more names of the databases to be created.
#      If more than one name is provided it is in the form of a quoted string
#      with the names separated by spaces.
#
# Assumptions:
#   1. If running in a container in a pod, a kubernetes config context is
#      auto-magically created and kubectl commands "just work."
#      If running outside of a kube pod, it is assumed the user has a current
#      kubernetes context for the admin user.
#
#   2. If a Cloudant DB server host name is not provided it is assumed
#      this script is being run in the context of a Kubernetes pod and the
#      cloudantdb.kube-system host is used.  If this script is running at
#      a host command line on a master node, then localhost needs to be
#      provided for the --dbhost argument value.
#

function usage {
  echo ""
  echo "Usage: create-database.sh [options]"
  echo "   --dbhost <hostname|ip_address>   - (optional) Host name or IP address of the Cloudant DB service provider"
  echo "                                      For example, one of the ICP master nodes."
  echo "                                      Defaults to cloudantdb.kube-system."
  echo ""
  echo "   --dbnames <name_list>            - (required) One or more names of the databases to be created."
  echo "                                      If more than one name is provided it must be a quoted string of"
  echo "                                      space separated names."
  echo ""
  echo "   --help|-h                        - emit this usage information"
  echo ""
  echo " - and -- are accepted as keyword argument indicators"
  echo ""
  echo "Sample invocations:"
  echo "  ./create-database.sh --dbhost master01.xxx.yyy --dbnames \"platform-db security-data\""
  echo ""
}

# import helper functions
. ./helper-functions.sh

############ "Main" starts here
SCRIPT=${0##*/}

info $LINENO "BEGIN $SCRIPT"

dbhost=""
dbnames=""

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
    -h|--help ) usage; exit
                ;;

    -dbhost|--dbhost)  dbhost=$2; shift
                ;;

    -dbnames|--dbnames)  dbnames=$2; shift
                ;;

    * ) usage;
        info $LINENO "ERROR: Unknown option: $arg in command line."
        exit 1
                ;;
  esac
  # shift to next key-value pair
  shift
done

if [ -z "$dbhost" ]; then
  dbhost=cloudantdb.kube-system
fi
info $LINENO "Cloudant DB host: $dbhost"


if [ -z "$dbnames" ]; then
  info $LINENO "ERROR: A list of database names (--dbnames) is required."
  exit 2
fi

currentDBs=$(getCloudantDatabaseNames $dbhost)

for name in $dbnames; do
  dbexists=$(echo "$currentDBs" | grep $name)
  if [ -z "$dbexists" ]; then
    info $LINENO "Creating database: $name on Cloudant instance host: $dbhost"
    createDatabase $dbhost $name
  else
    info $LINENO "Database: $name already exists on Cloudant instance host: $dbhost"
  fi
done

info $LINENO "END $SCRIPT"
