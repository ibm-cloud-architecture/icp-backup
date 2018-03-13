# Back up and restore the Cloudant database in IBM Cloud Private

IBM Cloudant local is used by IBM Cloud Private(ICP) to store information for OIDC service, metering service (IBM® Cloud Product Insights), Helm repository server, and Helm API server.
It runs as a kubernetes Statefulset and mount to local host path. The StatefulSet is exposed as HeadLess service as “cloudantdb”.
There are 2 databases holding the ICP metadata:

* _users
* helm_repos
* metrics
* metrics_app
* platform-db
* security-data
* stats
* tgz_files_icp

In this page, we'll describe how to back up and restore the Cloudant local db in IBM Cloud Private.

A collection of scripts in the `../scripts/cloudant` directory are to be used to do backup and restore of the ICP Cloudant databases.  See [ICP Cloudant Backup and Restore Scripts](../scripts/cloudant/ICP_cloudant_backup_and_restore.md)

## Getting started

* A single ICP cluster may be used to simulate a backup, failure and recovery scenario.  First, a full Cloudant backup is taken. Then Cloudant databases are deleted to simulate failure.  The databases are recreated and the backups are restored.   

* If you have the luxury of being able to deploy two ICP clusters, then you can perform a more realistic test of the Cloudant database backup and recovery process. In this document, the ICP cluster where the backups occur is referred to as the *source* cluster.  The other ICP cluster, where the restores occur, is referred to as the *target* cluster.  *NOTE:* The *target* ICP cluster must be deployed using the same IP addresses as the *source* ICP cluster.

* Add some things to the *source* ICP cluster such as:
  - Define at least one additional Helm repo, and some additional helm charts.  
  - If it is relatively convenient, configure the *source* ICP cluster to use LDAP for authentication.
  - Define a team with users from the LDAP.  Define the resource access of the team.


* Determine a host to use for a "staging" host where the backup and restore operations will occur.  It is recommended that the staging host be an independent machine with network connectivity to the master nodes of the "source" and "target" ICP clusters.  The staging server is intended to be more than a "minimal" server installation with a window manager, browser and other software that makes system administration more convenient. In this documentation it is assumed the staging host is not a member of either the source or target ICP clusters.

* The user of the staging host needs to have sudo access to the staging host in order to install software.  If that is not possible, then a system administrator will need to perform the software installation steps described below.

* On the staging host, create a staging directory.  This can be a directory in the home directory of the user.

* From the staging directory, clone this github project:
```
cd staging
git clone https://github.com/ibm-cloud-architecture/icp-backup.git
```

* Copy all the shell scripts in `./icp-backup/scripts/cloudant` to the staging directory.
```
cp ./icp-backup/scripts/cloudant/*.sh .
```

* Create a `logs` directory in the staging directory.  This will be used to hold stdout/stderr log files from the backup and restore utilities.
```
mkdir logs
```

* Run each of the *install* scripts, as needed.  (*NOTE:* The installation scripts are Ubuntu specific.)  The following software needs to be installed on the staging host:
  - kubectl
  - node (The provided script installs Node 9.x. Couchbackup requires at least Node 6.3.)
  - npm
  - jq
  - couchbackup
  - couchdb-cli
```
./01_install-kubectl.sh
./02_install-node9x.sh
./03_install-npm-latest.sh
./04_install-cloudant-utils.sh
./05_install-jq.sh
```  

* Working with two ICP clusters, a source and target cluster.
  - If you have the luxury of testing backup and restore on two ICP clusters then:
  - On the staging host, open two shell windows
  - One shell will be configured to work with the *source* ICP cluster. This will be referred to as the *source* shell window.
  - The other shell will be configured to work with the *target* ICP cluster.  This will be referred to as the *target* shell window.

* Working with a single ICP cluster
  - If you have one ICP cluster available for testing backup and restore, then:
  - You only need one kubectl context to be established in one shell window.
  - Failures will be simulated by deleting Cloudant databases on the ICP cluster. Scripts are described in the sections below to delete and re-create Cloudant databases.

* Configure a `kubectl` context in the **source** shell window where the Cloudant backup scripts are to be run.
  - Log in as a *cluster administrator* to the ICP console of the *source* ICP cluster. (The hard-wired cluster administrator is admin.)
  - Under the user icon in the
  ![admin](cloudant/UserName.png)
  - Click Configure Client
  - Click the blue icon in the text area:
  ![icon](cloudant/Icon.png)
  - Paste in your shell terminal on the staging host.
  - Run the script to set the preferred namespace to `kube-system`.
```
./set-namespace-kube-system.sh
```

* If it is difficult to cut-and-paste directly to the shell window on the staging server, then use the `icp-client-config.sh` script as a vehicle to get the `kubectl` context set.  Copy the script to a machine where you can cut-and-paste.  Cut-and-paste the client config `kubectl` commands into the script file as noted in the body of the `icp-client-config.sh` script. Then copy the script back to the staging server and execute it.  The `icp-client-config.sh` script includes a line at the end to set the preferred namespace to `kube-system`.

*NOTE:* The authentication token in the client configuration (kubectl context) is good for 12 hours.  You will need to run through the above steps again once the authentication token expires.

* Configure a `kubectl` context in the **target** shell window where the Cloudant restore scripts are to be run.
  - Log into the *target* ICP console as a cluster administrator, e.g., admin.
  - Repeat the above steps for configuring the `kubectl` context in the *target* shell window.

## Expose cloudantdb as a NodePort service

ICP packages the cloudantdb as a kubernetes headless service. For the purposes of backup and restore it needs to be externalized to a NodePort so that the backup and restore utilities can be run from outside of ICP cluster.

*NOTE: Another approach is to deploy a cloudant backup kubernetes job into the ICP that connects to the cloudantdb service, and perform a scheduled backup, .e.g, on a daily basis.*

On the staging host, run the script below in both the *source* shell window and the *target* shell window.

```
./externalize-cloudantdb-service.sh
```
# ICP Cloudant database backup and restore experiments

*NOTE:* In the sample command lines, the timestamp in the log file names is a convention intended to differentiate the log files as multiple runs of a given utility are executed. A timestamp may look like 2018-03-12-01, meaning, *12 MAR 2018* log file 01. If the same utility is run again on the same day the file portion would be incremented to 02, and so on. The user can use some other convention to differentiate the log files.  

*NOTE:* In the commands below the ICP host name used for the `--dbhost` parameter is shown as `master01`.  This represents one of the master nodes in an HA ICP cluster.  When the actual utilities are run an actual host name or IP address for a master node needs to be used.

For information on the scripts described in this section, see [ICP Cloudant Backup and Restore Scripts](../scripts/cloudant/ICP_cloudant_backup_and_restore.md)

## Back up the Cloudant databases

In an ICP HA environment, Cloudant DB runs in a cluster that spread across multiple ICP master nodes. The most reliable approach is to use the [Cloudant DB backup and restore facility](https://developer.ibm.com/clouddataservices/2016/03/22/simple-couchdb-and-cloudant-backup/).

In the *source* shell window run the `cloudant-backup.sh` script:
```
./cloudant-backup.sh --dbhost master01 2>&1 | tee logs/backup-dbs-timestamp-01.log
```
The above command will connect to the ICP cluster, and make a backup of all the ICP Cloudant databases.  The backups will be in a time stamped directory in a `backups` directory created in the current working directory.

## Simulate a loss of the ICP Cloudant database

Simulate a loss of the an ICP Cloudant database. Follow these steps to delete some data:

* Delete a Couch database:

```
./delete-database.sh --dbhost master01 --dbnames "helm_repos platform-db security-data" 2>&1 | tee logs/delete-dbs-timestamp-01.log
```

* Then recreate the databases (now empty):

```
./create-database.sh --dbhost master01 --dbnames "helm_repos platform-db security-data" 2>&1 | tee logs/create-dbs-timestamp-01.log
```

Use the command described in the next section to restore the content of the deleted databases.

## Restore your ICP Cloudant database

In the command below the time stamp in the backup directory name was generated by the `cloudant-backup.sh` utility and has the form: `YYYY-mm-dd-HH-MM-SS`. (The shell command: `date +%Y-%m-%d-%H-%M-%S` is used to create the timestamp.)  The timestamp in the log file name is merely a convention as described above.)

```
./cloudant-restore --dbhost master01 --backup-dir ./backups/icp-cloudant-backup-timestamp 2>&1 | tee logs/restore-dbs-timestamp-01.log
```

The above command will restore all the databases in the given directory that have a backup file in that directory.  (By default the `cloudant-backup.sy` script would have backed up all of the ICP Cloudant databases.) A list of databases with a backup file in the directory is stored in a file in that directory named `dbnames.sh`.  The `cloudant-restore.sh` utility *sources* the `dbnames.sh` file to access the list in an environment variable named `BACKED_UP_DBNAMES`.

To restore only a subset of the ICP Cloudant databases, the `--dbnames` parameter can be used to provide a list of databases to restore.

```
./cloudant-restore --dbhost master01 --backup-dir ./backups/icp-cloudant-backup-timestamp --dbnames "helm_repos platform-db security-data" 2>&1 | tee logs/restore-dbs-timestamp-02.log
```

The above command restores just the `helm-repos`, `platform-db` and `security-data` databases from backup files in the given backup directory.
