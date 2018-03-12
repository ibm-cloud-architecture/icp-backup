#!/bin/bash
#
# Delete one or more ICP Cloudant databases.
#
# Pre-reqs:
#    kubectl is needed to interact with the ICP cluster.
#    jq is needed to do JSON parsing.
#    coucher-cli is used to delete databases. 
#
# INPUTS:
#   1. Host name (FQDN) or IP address of the Cloudant DB server. (optional)
#      Defaults to localhost. This needs to be one of the ICP master nodes
#      where the Cloudant database service is running.
#
#   2. One or more names of the databases to be deleted.
#      If more than one name is provided it is in the form of a quoted string
#      with the names separated by spaces.
#
# Assumptions:
#   1. The user has a current kubernetes context for the admin user.
#
#   2. If a Cloudant DB server host name is not provided it is assumed
#      this script is being run on the Cloudant DB server host as
#      localhost is used in the Cloudant DB URL.
#

function usage {
  echo ""
  echo "Usage: delete-database.sh [options]"
  echo "   --dbhost <hostname|ip_address>   - (optional) Host name or IP address of the Cloudant DB service provider"
  echo "                                      For example, one of the ICP master nodes."
  echo "                                      Defaults to localhost."
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
  echo "  ./delete-database.sh --dbhost master01.xxx.yyy --dbnames \"platform-db security-data\"" 
  echo ""
}

# import helper functions
. ./helperFunctions.sh

# MAIN

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
  dbhost=localhost
fi
info $LINENO "Cloudant DB host: $dbhost"


if [ -z "$dbnames" ]; then
  info $LINENO "ERROR: A list of database names (--dbnames) is required."
  exit 2
fi

currentDBs=$(getCloudantDatabaseNames $dbhost)

for name in $dbnames; do
  dbexists=$(echo "$currentDBs" | grep $name)
  if [ -n "$dbexists" ]; then
    info $LINENO "Deleting database: $name on Cloudant instance host: $dbhost"
    deleteDatabase $dbhost $name
  else
    info $LINENO "Database: $name does not exist on Cloudant instance host: $dbhost"
  fi
done


