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
#
# DESCRIPTION:
#   Count the number of backup directories in the backup home directory.
#   Compare the actual count with the retention limit and delete the oldest
#   directories until the count is at the retention limit.
#
# INPUTS:
#   1. Path to backup directories home. (optional)
#      The backup directories home defaults to "backups" in the current
#      working directory.
#
# ASSUMPTIONS:
#   1. It is assumed that all directories in the backup home directory
#      that start with "icp-cloudant-backup" are backup directories.
#
#   2. User has write permission for the backups directory home.
#

function usage {
  echo ""
  echo "Usage: backup-cleanup.sh [options]"
  echo "   --backup-home <path>             - (optional) Full path to a backups home directory."
  echo "                                      Defaults to backups in current working directory."
  echo ""
  echo "   --retain <count>                 - (optional) Number of backups to retain."
  echo "                                      Defaults to 5"
  echo ""
  echo "   --help|-h                        - emit this usage information"
  echo ""
  echo "Sample invocations:"
  echo "  ./backup-cleanup.sh"
  echo "  ./backup-cleanup.sh --backup-home /data/backups"
  echo ""
  echo " User is assumed to have write permission on backup home directory."
  echo ""
}

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


############ "Main" starts here
SCRIPT=${0##*/}

info $LINENO "BEGIN $SCRIPT"

backupHome=""

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

    -retain|--retain )  retainCount=$2; shift
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
  backupHome="${PWD}/backups"
fi
info $LINENO "Backup home directory is: $backupHome"

if [ -z "$retainCount" ]; then
  retainCount=5
fi
info $LINENO "Retaining $retainCount backup directories."

allBackupDirs=$( ls "${backupHome}" | grep icp-cloudant-backup )
keepBackupDirs=$( ls -rt "${backupHome}" | grep icp-cloudant-backup | tail -${retainCount} )

for backupDir in $keepBackupDirs; do
  info $LINENO "Keeping backup directory: ${backupHome}/$backupDir"
done

for backupDir in $allBackupDirs; do
  if ! $(member "$backupDir" "$keepBackupDirs"); then
    rm -rf "${backupHome}/${backupDir}"
    info $LINENO "Removed backup directory: ${backupHome}/$backupDir"
  fi
done

info $LINENO "END $SCRIPT"
