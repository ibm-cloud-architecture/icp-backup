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
# Functions to assist with mariadb backup and restore.
# Sourced by other scripts that need to use these functions.
#
# Pre-reqs:
#    1. bash is needed for various scripting conventions
#       Experiments with Ash in Alpine showed that bash is needed.
#    2. kubectl is needed to interact with the ICP cluster.
#    3. jq is needed to do JSON parsing.
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


getMariaDBPassword () {
  ### Get the mariadb password from kube secret
  local mariadb_password=$(kubectl get secret platform-mariadb-credentials --namespace=kube-system -o json | jq '.["data"]["OAUTH2DB_PASSWORD"]')

  # Strip leading and trailing double quotes
  mariadb_password=${mariadb_password#\"}
  mariadb_password=${mariadb_password%\"}

  echo $mariadb_password | base64 -d
}


getMariaDBUser () {
  ### Get the mariadb user from kube secret
  local mariadb_user=$(kubectl get secret platform-mariadb-credentials --namespace=kube-system -o json | jq '.["data"]["OAUTH2DB_USER"]')

  # Strip leading and trailing double quotes
  mariadb_user=${mariadb_user#\"}
  mariadb_user=${mariadb_user%\"}

  echo $mariadb_user | base64 -d
}


getMariaDBPort () {
  local port=$(kubectl --namespace kube-system get service/mariadb -o json| jq '.["spec"]["ports"][0]["port"]')

  echo $port
}


getDatabaseNames () {
  # $1 is MariaDB host name or IP address.
  # localhost is valid if running script on MariaDB host.
  # mariadb.kube-system is valid when running in a container.
  # If the container is running in the kube-system namespace, then mariadb is sufficient.
  local user=$(getMariaDBUser)
  local password=$(getMariaDBPassword)
  local host=$1
  local port=$(getMariaDBPort)

  if [ -z "$host" ]; then
    host=mariadb.kube-system
  fi

  local allDBs=$(mysql --host=$host --port=$port --user=$user --password=$password -e 'show databases')

  # Replace newlines with space character and remove double quotes
  allDBs=$(echo "$allDBs" | tr '\n' ' ' | tr -d '"')

  # Remove the word Database.
  allDBs="${allDBs//Database/}"

  # Remove leading and trailing spaces.
  allDBs=$(echo "$allDBs" | awk '{$1=$1};1')

  echo "$allDBs"
}


exportAllDBNames () {
  # Export the names of all databases in the MariaDB instance.
  # $1 is the MariaDB host name or IP address
  #    localhost is valid if running script on MariaDB host.
  # $2 is the path to directory where databases names are to be exported
  local dbhost=$1
  local destDir=$2

  if [ -z "$destDir" ]; then
    destDir="$PWD"
  fi

  local allDBs=$(getDatabaseNames $dbhost)
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
  # $2 is the MariaDB database name
  local backupDir=${1%/}
  local fileName="$2-backup.sql"
  echo "${backupDir}/${fileName}"
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
