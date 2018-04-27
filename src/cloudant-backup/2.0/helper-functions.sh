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

# DESCRIPTION:
# Functions to assist with cloudant backup and restore.
# Sourced by other scripts that need to use these functions.
#
# Pre-reqs:
#    1. bash is needed for various scripting conventions
#       Experiments with Ash in Alpine showed that bash is needed.
#    2. kubectl is needed to interact with the ICP cluster.
#    3. jq is needed to do JSON parsing.
#    4. curl is needed to interact with the Cloudant REST APIs
#    5. coucher CLI utility is used to create and delete databases.
#
# ASSUMPTIONS:
#   1. If running externally (outside a container) kubectl login context has
#      been established.
#   2. If running in a container a kubectl "just works" without a login.
#

# The info() function is used to emit log messages.
# It is assumed that SCRIPT is set in the caller.
function info {
  local lineno=$1; shift
  local ts=$(date +[%Y/%m/%d-%T])
  echo "$ts $SCRIPT($lineno) $*"
}


# member() returns 0 if the first argument is a member of the second argument.
# $1 is the string that represents the item of interest
# $2 is the string that represents a list of items separated by space characters.
# If item is in list the status 0 is returned otherwise status 1 is returned.
# NOTE: When using member() in a condition do not use [ ] or [[ ]] expressions.
#    Example:  if $(member "A" "a B C d A"); then
#                echo "A is a member"
#              else
#                echo "A is not a member"
#              fi
#    if ! $(member "A" "a B C d A"); when you need not member().
#
#    It is likely the list parameter is going to be a shell variable,
#    in which cast it must be double quoted on the invocation:
#        $(member $item "${some_list}")
#
function member() {
  local item=$1
  local list=$2

  rc=1
  for x in $list; do
  	if [ "$x" == "$item" ]; then
  	  rc=0
  	  break
  	fi
  done

  return $rc
}


getCloudantPassword () {
  ### Get the cloudant password from kube secret
  raw_secret=$(kubectl get secret cloudant-credentials --namespace=kube-system -o json | jq '.["metadata"]["annotations"]["kubectl.kubernetes.io/last-applied-configuration"]')

  # Remove trailing double quote and what looks like a newline but is actually \n (3 charaters to remove).
  raw_secret=${raw_secret%???}

  # Remove leading double quote.
  raw_secret=${raw_secret#\"}

  # Remove all back slash characters.
  secret=$(echo $raw_secret | tr -d '\\')

  # Parse out the part of the secret with the data we are interested in.
  cloudant_password=$(echo $secret | jq '.["data"]["cloudant_password"]')

  # Strip leading and trailing double quotes
  cloudant_password=${cloudant_password#\"}
  cloudant_password=${cloudant_password%\"}

  echo $cloudant_password | base64 -d
}

# The getCloudantNodePort() function assumes an "external" service has been defined
# named cloudantdb-ext that exposes the cloudantdb.kube-system service on a nodePort.
# It is assumed the second port in the ports list (position 1) is the HTTP port.
getCloudantNodePort () {

  local port=$(kubectl --namespace=kube-system get svc cloudantdb-ext -o json | jq '.["spec"]["ports"][1]["nodePort"]')

  echo $port
}


# The getCloudantExtURL() function is intended for use with backups that are done
# from an external (outside a container) shell.  It assumes there is a cloudantdb-ext
# service defined that exposes the cloudantdb service on a nodePort.
#
getCloudantExtURL () {
  # Construct the cloudant URL echo it back to caller.
  # $1 is Cloudant DB host name or IP address.
  # defaults to localhost
  # admin is assumed to be the cloudant user.

  local dbhost=$1

  if [ -z "$dbhost" ]; then
    dbhost=localhost
  fi

  local password=$(getCloudantPassword)
  local port=$(getCloudantNodePort)

  echo "http://admin:$password@$dbhost:$port"

}

# For the cloudantdb service in the kube-system namespace, the second port in the ports
# list is the HTTP port.  That is position 1 in the list.
getCloudantHTTPPort () {
  local port=$(kubectl --namespace=kube-system get svc cloudantdb -o json | jq '.["spec"]["ports"][1]["port"]')

  echo $port
}


# The getCloudantURL() function is intended for use when running in a container.
# The cloudantdb service host defaults to cloudantdb.kube-system.
getCloudantURL () {
  # Construct the cloudant URL echo it back to caller.
  # User is assumed to be admin.

  local dbhost=$1
  local port=$2
  local user=admin
  local password=$(getCloudantPassword)

  if [ -z "$dbhost" ]; then
    dbhost=cloudantdb.kube-system
  fi

  if [ -z "$port" ]; then
    port=$(getCloudantHTTPPort)
  fi

  echo "http://$user:$password@$dbhost:$port"

}

# The _all_dbs REST API returns a JSON list:
#   [ "_users", "helm_repos", "metrics", "metrics_app", "platform-db", "security-data", "stats", "tgz_files_icp" ]
#   The actual output from jq has newlines after each item in the list.
#   Also note the leading and trailing white space character of the string inside the brackets which needs to
#   be trimmed out.

getCloudantDatabaseNames () {
  # $1 is Cloudant DB host name or IP address.
  # localhost is valid if running script on Cloudant DB host.
  # cloudantdb.kube-system is valid when running in a container.
  # If the container is running in the kube-system namespace, then cloudantdb is sufficient.

  local cloudantURL=$(getCloudantURL $1)
  local allDBs=$(curl --silent $cloudantURL/_all_dbs | jq '.')

  # Use tr to remove the newlines, double quotes, left and right square bracket and commasa.
  # The awk idiom trims leading and trailing white space.
  allDBs=$(echo "$allDBs" | tr -d '[\n",]' | awk '{$1=$1};1' )

  echo "$allDBs"
}


exportCloudantDatabaseNames () {
  # $1 is the Cloudant DB host name or IP address
  #    localhost is valid if running script on Cloudant DB host.
  # $2 is the path to directory where databases names are to be exported
  local dbhost=$1
  local destDir=$2

  if [ -z "$destDir" ]; then
    destDir="$PWD"
  fi

  local allDBs=$(getCloudantDatabaseNames $dbhost)
  local dest="$destDir/dbnames.sh"

  if [ -f "$dest" ]; then
    # dbnames.sh already exists
    exported=$(grep ALL_DBS "$dest")
    if [ -z "$exported" ]; then
      # ALL_DBS not written in dbnames.sh, append it
      echo "export ALL_DBS=\"$allDBs\"" >> "$dest"
    fi
  else
    # Create dbnames.sh and write ALL_DBS to it
    echo "export ALL_DBS=\"$allDBs\"" > "$dest"
    chmod +x "$dest"
  fi
}


exportDBnames () {
  # Export the given dbnames to dbnames.sh in the given directory.
  # INPUTS:
  #   1. Quoted string space separated list of database names.
  #   2. Destination directory path.  If not provided, current working
  #      directory is used.

  local dbnames=$1
  local destDir=$2

  if [ -z "$destDir" ]; then
    destDir=$PWD
  fi

  local dest="$destDir/dbnames.sh"

  if [ -f "$dest" ]; then
    # dbnames.sh already exists
    exported=$(grep -q BACKED_UP_DBNAMES "$dest")
    if [ -z "$exported" ]; then
      # BACKED_UP_DBNAMES not written in dbnames.sh, append it
      echo "export BACKED_UP_DBNAMES=\"$dbnames\"" >> "$dest"
    fi
  else
    # Create dbnames.sh and write BACKED_UP_DBNAMES to it
    echo "export BACKED_UP_DBNAMES=\"$dbnames\"" > "$dest"
    chmod +x "$dest"
  fi
}


makeBackupFilePath () {
  # Return the full path of the file name with the backup for the given database name.
  # $1 is the backup directory path
  # $2 is the Cloudant database name
  local fileName="$2-backup.json"
  echo "$1/${fileName}"
}

createDatabase () {
  # Create a Cloudant database
  # $1 is the host name of the Cloudant DB instance
  #    localhost is valid if the script is run on the instanct host.
  # $2 is the database name
  #
  # Both parameters are required.

  local dbhost=$1
  local dbname=$2

  local cloudantURL=$(getCloudantURL $dbhost)

  coucher database -c $cloudantURL -a create -d $dbname

}


deleteDatabase () {
  # Delete a Cloudant database
  # $1 is the host name of the Cloudant DB instance
  #    localhost is valid if the script is run on the instanct host.
  # $2 is the database name
  #
  # Both parameters are required.

  local dbhost=$1
  local dbname=$2

  local cloudantURL=$(getCloudantURL $dbhost)

  coucher database -c $cloudantURL -a delete -d $dbname

}
