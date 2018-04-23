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
#   Get a list of all the ICP MariaDB databases defined and write it to stdout.
#   It is handy to be able to quickly see the list of databases names for testing.
#
# Pre-reqs:
#    1. bash is needed for various scripting conventions
#       Experiments with Ash in Alpine showed that bash is needed.
#    2. kubectl is needed to interact with the ICP cluster.
#    3. jq is needed to do JSON parsing.
#
#
# INPUTS:
#   1. Kubernetes service host name or host name (FQDN) or IP address of the
#      MariaDB server. (optional)
#      Defaults to mariadb.kube-system.
#      If running outside of a container, then a machine host name needs to be
#      passed in, even localhost.
#
# Assumptions:
#   1. The user has a current kubernetes context for the admin user.
#
#   2. If a MariaDB service host name is not provided it is assumed
#      this script is being run in a container and mariadb.kube-system
#      is used as the service host name.
#

function usage {
  echo ""
  echo "Usage: get-database-names.sh [options]"
  echo "   --dbhost <hostname|ip_address>   - (optional) Host name or IP address of the MariaDB service provider"
  echo "                                      Defaults to mariadb.kube-system"
  echo ""
  echo "   --help|-h                        - emit this usage information"
  echo ""
  echo " - and -- are accepted as keyword argument indicators"
  echo ""
  echo "Sample invocations:"
  echo "  ./get-database-names.sh"
  echo "  ./get-database-names.sh --dbhost master01.xxx.yyy"
  echo ""
}

# import helper functions
. ./helper-functions.sh

# MAIN
SCRIPT=${0##*/}

info $LINENO "BEGIN $SCRIPT"

dbhost=""

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

    * ) usage; info $LINENO "ERROR: Unknown option: $arg in command line."
        exit 1
                ;;
  esac
  # shift to next key-value pair
  shift
done

if [ -z "$dbhost" ]; then
  dbhost=mariadb.kube-system
fi
info $LINENO "MariaDB host: $dbhost"

allDBs=$(getDatabaseNames $dbhost)

if [ -z "$allDBs" ]; then
  info $LINENO "No databases are defined in the MariaDB instance hosted by: $dbhost"
  info $LINENO "END $SCRIPT"
else
  info $LINENO "END $SCRIPT"
  info $LINENO "ICP MariaDB database names:"
  echo "\"$allDBs\""
fi
