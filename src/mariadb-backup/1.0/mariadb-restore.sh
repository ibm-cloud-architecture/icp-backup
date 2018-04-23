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
#   Restore ICP MariaDB databases
#
#   For more information from MySQL documentation see:
#   https://dev.mysql.com/doc/refman/8.0/en/backup-and-recovery.html
#
# INPUTS:
#   1. Backup home directory.  (optional)
#      Defaults to the backups directory in the current working directory.
#
#   2. Path to backup directory. (optional)
#      Defaults to most recent backup in the backup home directory.
#      Each backup gets its own directory with a timestamp.
#
#   3. Kubernetes service host name, host name (FQDN) or IP address of the
#      MariaDB server. (optional) Defaults to mariadb.kube-system.
#      If running outside of a container, this needs to be one of the ICP
#      master nodes where the MariaDB database service is running. If this
#      script is running at a host command line on a master node, then localhost
#      needs to be provided for the --dbhost argument value.
#
#   4. Database names of databases to restore. (optional)
#      Defaults to all the databases that were backed up by the mariadb-backup.sh
#      script.  The dbnames.sh file in the backup directory is sourced.
#      The variable BACKED_UP_DBNAMES holds the list of database backups in the
#      given backup directory.
#
# Pre-reqs:
#    1. bash is needed for various scripting conventions
#         Experiments with Ash in Alpine showed that bash is needed.
#    2. kubectl is required by the helper-functions.
#    3. mysql CLI client is required to do the restore.
#
#
# Assumptions:
#   1. If running in a container in a pod, a kubernetes config context is
#      auto-magically created and kubectl commands "just work."
#      If running outside of a kube pod, it is assumed the user has a current
#      kubernetes context for the admin user.
#
#   2. User has read permission for the backups directory home.
#
#   3. If a MariaDB server host name is not provided it is assumed
#      this script is being run in the context of a Kubernetes pod and the
#      mariadb.kube-system host is used.  If this script is running at
#      a host command line on a master node, then localhost needs to be
#      provided for the --dbhost argument value.
#
#   4. The backup was created with the mariadb-backup.sh script that
#      is included in the git repo with this script.  The content of
#      the backup directory is expected to have a dbnames.sh script
#      that holds a list of databases that were backed up.
#
function usage {
  echo ""
  echo "Usage: mariadb-restore.sh [options]"
  echo "   --dbhost <hostname|ip_address>   - (optional) Service name, host name or IP address of the"
  echo "                                      ICP MariaDB service provider. For example, one of the"
  echo "                                      ICP master nodes."
  echo "                                      Defaults to mariadb.kube-system."
  echo ""
  echo "   --backup-home <path>             - (optional) Full path to a backups home directory."
  echo "                                      Defaults to backups in current working directory."
  echo ""
  echo "   --backup-dir <path>              - (optional) Path to a backup directory."
  echo "                                      Defaults to the most recent backup directory in the backup home directory."
  echo "                                      A valid backup directory will have a time stamp in its name and"
  echo "                                      a file named dbnames.sh that is executable along with the backup"
  echo "                                      JSON files and backup log files."
  echo ""
  echo "   --dbnames <name_list>            - (optional) Space separated list of database names to restore."
  echo "                                      The dbnames list needs to be quoted."
  echo "                                      Defaults to all databases with backup files in the given backup directory."
  echo ""
  echo "   --help|-h                        - emit this usage information"
  echo ""
  echo " - and -- are accepted as keyword argument indicators"
  echo ""
  echo "Sample invocations:"
  echo "  ./mariadb-restore.sh --backup-home /data/backups"
  echo "  ./mariadb-restore.sh --dbhost master01.xxx.yyy --backup-dir ./backups/icp-mariadb-backup-2018-03-10-21-08-41"
  echo ""
  echo " User is assumed to have read permission on backup home directory."
  echo " User is assumed to have a valid kubernetes context with admin credentials."
  echo ""
}


# import helper functions
. ./helper-functions.sh

############ "Main" starts here
SCRIPT=${0##*/}

info $LINENO "BEGIN $SCRIPT"

backupHome=""
backupDir=""
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

    -backup-dir|--backup-dir )  backupDir=$2; shift
                ;;

    -backup-home|--backup-home )  backupHome=$2; shift
                ;;

    -dbhost|--dbhost)  dbhost=$2; shift
                ;;

    -dbnames|--dbnames)  dbnames=$2; shift
                ;;

    * ) usage; info $LINENO "ERROR: Unknown option: $arg in command line."
               exit 1
                ;;
  esac
  # shift to next key-value pair
  shift
done


if [ -z "$backupHome" ]; then
  backupHome="${PWD%/}/backups"
fi

if [ -z "$backupDir" ]; then
  info $LINENO "Most recent backup directory in $backupHome will be used for the MariaDB database restore."
  backupDirName=$( ls -rt "${backupHome}" | grep icp-mariadb-backup | tail -1 )
  if [ -z "$backupDirName" ]; then
    info $LINENO "ERROR: There are no directories in $backupHome with icp-mariadb-backup in the directory name."
    exit 2
  fi
  # strip potential trailing slash from backupHome
  backupDir="${backupHome%/}/${backupDirName}"
fi

if [ ! -d "$backupDir" ]; then
  info $LINENO "ERROR: The backup directory does not exist or is not a directory: $backupDir"
  exit 3
fi

info $LINENO "Backup directory path: $backupDir"

dbnamesScriptPath="${backupDir%/}/dbnames.sh"
if [ ! -f "$dbnamesScriptPath" ]; then
  info $LINENO "ERROR: The backup directory, $backupDir, is missing the dbnames.sh script and is invalid."
  exit 4
fi

source "$dbnamesScriptPath"
# ALL_DBS and BACKED_UP_DBNAMES are exported in dbnames.

if [ -z "$BACKED_UP_DBNAMES" ]; then
  info $LINENO "ERROR: The backup directory does not appear to have any databases that were backed up. BACKED_UP_DBNAMES is empty."
  info $LINENO "Backup directory: $backupDir"
  info $LINENO "dbnames.sh content:"
  cat "$dbnamesScriptPath"
  exit 5
else
  info $LINENO "ICP MariaDB database backups for: \"$BACKED_UP_DBNAMES\" in: $backupDir"
fi

if [ -z "$dbhost" ]; then
  dbhost=mariadb.kube-system
fi
info $LINENO "MariaDB host: $dbhost"

if [ -z "$dbnames" ]; then
  # If dbnames was not provided on commmand line then restore all that have a backup
  # in the backup directory.
  dbnames="$BACKED_UP_DBNAMES"
else
  # Make sure all user provided dbnames are valid for the given backup directory.
  ERROR=""
  for name in $dbnames; do
    isvalid=$(echo "$BACKED_UP_DBNAMES" | grep $name)
    if [ -z "$isvalid" ]; then
      info $LINENO "ERROR: The backup directory does not hold a backup for database name: \"$name\""
      ERROR="true"
    fi
  done
  if [ -n "$ERROR" ]; then
    info $LINENO "Valid ICP MariaDB database names:"
    echo "\"$ALL_DBS\""
    info $LINENO "Backup directory: $backupDir holds backups for databases:"
    echo "\"$BACKED_UP_DBNAMES\""
    exit 6
  fi
fi

info $LINENO "Databases to be restored: $dbnames"
info $LINENO "Backups will be restored from: $backupDir"

mariadb_user=$(getMariaDBUser)
if [ -z "$mariadb_user" ]; then
  info $LINENO "ERROR: Failed to get MariaDB user.  Check getMariaDBUser helper function."
  exit 7
fi
info $LINENO "MariaDB user: $mariadb_user"

mariadb_password=$(getMariaDBPassword)
if [ -z "$mariadb_password" ]; then
  info $LINENO "ERROR: Failed to get MariaDB password.  Check the getMariaDBPassword helper function."
  exit 8
fi

existing_dbnames=$(getDatabaseNames $dbhost)
# For mariadb backups created using mysqldump all the needed info to recreate
# the database is in the back-up sql file, with the execption of the database
# creation itself.  Before doing the restore the database must exist.
for dbname in $dbnames; do
  backupFilePath=$(makeBackupFilePath $backupDir $dbname)
  if [ ! -f "$backupFilePath" ]; then
    info $LINENO "ERROR: Backup file: $backupFilePath does not exist for database: $dbname"
  else
    if ! $(member "$dbname" "$existing_dbnames"); then
      info $LINENO "Database $dbname does not currently exist in the MariaDB instance, creating $dbname..."
      mysql --host=$dbhost --user=$mariadb_user --password=$mariadb_password -e "create database $dbname"
      rc=$?
      if [ "$rc" != "0" ]; then
        info $LINENO "ERROR: Failed to create database $dbname"
        continue
      else
        info $LINENO "Database $dbname created."
      fi
    fi
    info $LINENO "Restoring $dbname from $backupFilePath..."
    mysql --host=$dbhost --database=$dbname --user=$mariadb_user --password=$mariadb_password < "$backupFilePath"
    rc=$?
    if [ "$rc" != "0" ]; then
      info $LINENO "ERROR: Restore FAILED for $dbname. Returned status of: $rc."
    else
      info $LINENO "$dbname restore completed."
    fi
  fi
done

info $LINENO "END $SCRIPT"
