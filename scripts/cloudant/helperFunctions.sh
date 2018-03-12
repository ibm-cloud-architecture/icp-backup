#!/bin/bash

# Functions to assist with cloudant backup and restore.
# Sourced by other scripts that need to use these functions.

function info {
  local lineno=$1; shift
  ts=$(date +[%Y/%m/%d-%T])
  echo "$ts $SCRIPT($lineno) $*"
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


getCloudantNodePort () {

  local port=$(kubectl --namespace=kube-system get svc cloudantdb-ext -o json | jq '.["spec"]["ports"][1]["nodePort"]')

  echo $port
}


getCloudantURL () {
  # Construct the cloudant URL echo it back to caller.
  # $1 is Cloudant DB host name or IP address.
  # defaults to localhost

  local dbhost=$1

  if [ -z "$dbhost" ]; then 
    dbhost=localhost
  fi

  local password=$(getCloudantPassword)
  local port=$(getCloudantNodePort)

  echo "http://admin:$password@$dbhost:$port"

}

# The _all_dbs REST API returns a JSON list: 
#   [ "_users", "helm_repos", "metrics", "metrics_app", "platform-db", "security-data", "stats", "tgz_files_icp" ]
#   The actual output from jq has newlines after each item in the list.
#   Also note the leading and trailing white space character of the string inside the brackets which needs to
#   be trimmed out.

getCloudantDatabaseNames () {
  # $1 is Cloudant DB host name or IP address.
  # localhost is valid if running script on Cloudant DB host.

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
  echo "$1/$fileName"
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

