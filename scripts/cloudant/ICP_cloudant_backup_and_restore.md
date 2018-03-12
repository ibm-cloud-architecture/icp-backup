# ICP Cloudant Backup and Restore Scripts

The backup and restore scripts can be considered in two groups:
1. Installation and configuration scripts
2. Backup and restore utility scripts

## Installation and configuration scripts
- The installation and configuration scripts must be executed before using any of the backup and restore scripts.
- *NOTE:* The scripts are Ubuntu specific.  (*TODO* - Create equivalent scripts for RHEL.)
- The installation and configuration scripts have a number in the first part of the script name that indicates the order in which they are expected to be executed.

The following table describes briefly the purpose of each installation and configuration script.

|  **Script Name**                    |       **Comments**                                   |
|-------------------------------------|------------------------------------------------------|
|`01_clone-backup-git-repo.sh`          |Clone the git repot with the ICP backup artifacts and documentation.  |
|`02_install_kubectl.sh`                |Install kubectl which is needed to interact with the ICP kubernetes cluster |
|`03_installNode9x.sh`                  |Node is the implementation language of the Cloudant back and restore utilities used by the scripts.   |
|`04_installLatestNPM.sh`               |NPM is the node package manager and is needed to install various node packages.   |
|`05_installCloudantUtils.sh`           |Installs couchbackup (and restore) as well as couchdb-cli   |
|`06_install-jq.sh`                     |jq is used to parse JSON when interacting with the kubernetes cluster   |
|`07_ICPclientConfig.sh`                |Used to configure a current kubernetes context with admin access to the cluster.<br/>Sets the preferred namespace to kube-system.<br/>*NOTE:* Before running `07_ICPclientConfig.sh`, you need to paste in the `kubectl` client configuration commands that configure the context.<br/>The client configuration commands are available from the ICP console in the user icon drop-down menu.   |

## Backup and restore utility scripts
- The backup and restore utility scripts have pre-reqs that the following software is installed on the machine running the scripts:
  - kubectl
  - node (The provided script installs Node 9.x. Couchbackup requires at least Node 6.3.)
  - npm
  - jq
  - couchbackup
  - couchdb-cli

- The backup and restore utilities can be run on a host remote to the ICP master nodes as long as the Cloudant database server host name or IP address is provided using the `--dbhost` argument to the scripts.
- All backup and restore utility scripts have usage information available with the `--help` or `-h` option.
- All scripts assume the user has a current kubernetes context with "cluster administrator" access to the cluster.
- Backups are created in a backup directory with the name `icp-cloudant-backup-<timestamp>`, where `<timestamp>` has the form: `YYYY-mm-dd-HH-MM-SS`. (The shell command: `date +%Y-%m-%d-%H-%M-%S` is used to create the timestamp.)
- The file names in the backup directory have the form: `<database_name>-backup.json`.
- A "backup home" directory is where the time-stamped backup directory is created.  When a backup is invoked the user provides a path to the backup home directory using the `--backup-home` parameter to the `cloudant-backup.sh` script. The backup home is a directory of directories.
- When a backup is taken, the backup directory gets an executable file created in it named `dbnames.sh`. The `dbnames.sh` file is sourced by the `cloudant-restore.sh` script to get a list of the database names for which a backup is stored in the directory.  The backed up database names are the value of the `BACKED_UP_DBNAMES` environment variable exported in the `dbnames.sh` file.  

The following table describes briefly the role of each backup and restore utility script.

|  **Script Name**                    |       **Comments**                                   |
|-------------------------------------|------------------------------------------------------|
|`helperFunctions.sh`                 |This script is sourced by the other scripts for its collection of "helper" functions.<br/>This script is not intended to be run directly.|
|`get-database-names.sh`   |Get a list of ICP Cloudant database names.<br/>The list is returned as a quoted string with the names separated by a space character.  |
|`cloudant-backup.sh`   |Backup the ICP Cloudant databases.  The default behavior is to backup all databases to a time-stamped directory in `./backups`.<br/>The `--backup-home` parameter can be used to provide a path to the backup home.<br/>The `--dbnames` script option can be used to provide a list of 1 or more database names to be backed up.   |
|`cloudant-restore.sh`   |Restore ICP Cloudant databases. The path to a backup directory is a required input using the `--backup-dir` parameter.    |
|`create-database.sh`   |Create 1 or more databases with the given names in the ICP Cloudant database instance.<br/>The database names are provided using the `--dbnames` parameter.   |
|`delete-database.sh`   |Delete 1 or more databases with the given names in the ICP Cloudant database instance.<br/>The database names are provided using the `--dbnames` parameter.   |
