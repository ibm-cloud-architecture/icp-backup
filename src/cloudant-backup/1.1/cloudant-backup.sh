#!/bin/bash
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
#   Extract backups for all of the ICP Cloudant databases.
#   Write the backups to a timestamped directory in a given backups home directory.
#
# INPUTS:
#   1. Path to backup directories home. (optional) 
#      Each backup gets its own directory with a timestamp.
#      The timestamped backup directory for this backup will be created 
#      in the given backup directories home.  
#      The backup directories home defaults to "backups" in the current
#      working directory.
#
#   2. Host name (FQDN) or IP address of the Cloudant DB server. (optional)
#      Defaults to localhost. This needs to be one of the ICP master nodes
#      where the Cloudant database service is running.
#
#   3. Database names of databases to back up. (optional)
#      Defaults to all databases defined in the Cloudant instance.
#
# Assumptions:
#   1. The user has a current kubernetes context for the admin user.
#
#   2. User has write permission for the backups directory home.
#
#   3. If a Cloudant DB server host name is not provided it is assumed
#      this script is being run on the Cloudant DB server host as
#      localhost is used in the Cloudant DB URL.
#
function usage {
  echo ""
  echo "Usage: cloudant-backup.sh [options]"
  echo "   --dbhost <hostname|ip_address>   - (optional) Host name or IP address of the Cloudant DB service provider"
  echo "                                      For example, one of the ICP master nodes."
  echo "                                      Defaults to cloudant."
  echo ""
  echo "   --backup-home <path>             - (optional) Full path to a backups home directory."
  echo "                                      Defaults to directory /backup."
  echo ""
  echo "   --dbnames <name_list>            - (optional) Space separated list of database names to back up."
  echo "                                      The dbnames list needs to be quoted."
  echo "                                      Defaults to all databases defined in the Cloudant instance."
  echo ""
  echo "   --help|-h                        - emit this usage information"
  echo ""
  echo " - and -- are accepted as keyword argument indicators"
  echo ""
  echo "Sample invocations:"
  echo "  ./cloudant-backup.sh"
  echo "  ./cloudant-backup.sh --dbhost master01.xxx.yyy --backup-home /backups"
  echo ""
  echo " User is assumed to have write permission on backup home directory."
  echo " User is assumed to have a current kubernetes context with admin credentials."
  echo ""
}


# import helper functions
. ./helperFunctions.sh

# MAIN

backupHome=""
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
    -h|--help ) usage; exit 0
                ;;

    -backup-home|--backup-home )  backupHome=$2; shift
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


if [ -z "$backupHome" ]; then
  backupHome="/backup"
fi
info $LINENO "Backup directory will be created in: $backupHome"

if [ -z "$dbhost" ]; then
  dbhost=cloudantdb
fi
info $LINENO "Cloudant DB host: $dbhost"


port=$(getCloudantNodePort)
password=$(getCloudantPassword)

if [ -z "$port" ]; then
  info $LINENO "ERROR: port must be defined. Check getCloudantNodePort helper function."
  exit 1
fi

if [ -z "$password" ]; then 
  info $LINENO "ERROR: password must not be empty. Check getCloudantPassword helper function."
  exit 2
fi

info $LINENO "Cloudant NodePort: $port"

#cloudantURL=$(getCloudantURL $dbhost)

#info $LINENO "Cloudant URL: $cloudantURL"

#allDBs=$(curl --silent $cloudantURL/_all_dbs)

  cloudantURL=$(getCloudantURL $dbhost)
  info $LINENO "cloudantURL: $cloudantURL"

  c=$(curl --silent $cloudantURL/_all_dbs)
  info $LINENO "c: $c"

  allDBs=$(curl --silent $cloudantURL/_all_dbs | jq '.')
  info $LINENO "allDBs: $allDBs"

  # Use tr to remove the newlines, double quotes, left and right square bracket and commasa.
  # The awk idiom trims leading and trailing white space.
  allDBs=$(echo "$allDBs" | tr -d '[\n",]' | awk '{$1=$1};1' )
  info $LINENO "allDBs: $allDBs"

  echo "$allDBs"


allDBs=$(getCloudantDatabaseNames $dbhost)

if [ -z "$allDBs" ]; then
  info $LINENO "ERROR: Cloudant database name list must not be empty. Check getCloudantDatabaseNames helper function."
  exit 3
fi

if [ -z "$dbnames" ]; then
  dbnames="$allDBs"
else
  # make sure all user provided dbnames are valid
  ERROR=""
  for name in $dbnames; do
    isvalid=$(echo "$allDBs" | grep $name) 
    if [ -z "$isvalid" ]; then
      info $LINENO "ERROR: The name: \"$name\" is not a valid ICP Cloudant database name."
      ERROR="true"
    fi
  done
  if [ -n "$ERROR" ]; then
    info $LINENO "Valid ICP Cloudant database names: $allDBs"
    exit 6
  fi
fi

info $LINENO "Databases to be backed up: $dbnames"

# backup timestamp
ts=$(date +%Y-%m-%d-%H-%M-%S)
backupDir="${backupHome}/icp-cloudant-backup-$ts"

mkdir -p $backupDir
if [ "$?" != "0" ]; then 
  info $LINENO "ERROR: Failed to create: $backupDir"
  exit 4
fi

info $LINENO "Backups will be written to: $backupDir"

exportCloudantDatabaseNames $dbhost "$backupDir"
exportDBnames "$dbnames" "$backupDir"

for dbname in $dbnames; do
  couchbackup --url "http://admin:$password@$dbhost:$port" --log "$backupDir/$dbname-backup.log" --db $dbname > "$backupDir/$dbname-backup.json"
done


