# Back up and restore the MariaDB database in IBM Cloud Private

This document describes the ICP MariaDB backup and restore procedures implemented by the content in this repository.

The artifacts for the ICP MariaDB backup and restore procedures are available by cloning this Git repository: https://github.com/ibm-cloud-architecture/icp-backup

# Introduction to MariaDB in ICP

For those totally unfamiliar with MariaDB, visit the [MariaDB](https://mariadb.com/) web site to get acquainted.

The MariaDB instance in ICP is used to hold various tokens for users logged into ICP.  The tokens have a lifespan of 12 hours.  It can be argued that the MariaDB instance does not need to be backed up because its content is relatively transient.  However, at least one reason to back up the MariaDB databases is to be able to conveniently restore their schemas, if necessary.

The database of interest in the ICP MariaDB instance is named `OAuthDBSchema`.

The MariaDB instance is exposed on external port 3306 on the master nodes of the cluster.

In and ICP HA deployment, each master has its own MariaDB instance which stays synchronized with the MariaDB instance on the current master node.

Each master persists the MariaDB instance in `/var/lib/mysql`.  (Included with the scripts in `scripts/mariadb/ansible` is a script `archive_mariadb_on_masters.yml` that archives the `/var/lib/mysql` directory content in `/tmp` on the given masters nodes.)

If you want to work with the ICP MariaDB instance from the command line you will need to edit the config file: `/etc/my.cnf.d/mysql-clients.cnf` and add:
```
[client]
protocol=tcp
```
*WARNING:* Only expose the MariaDB instance via `tcp` for as long as needed to work with the instance.  When you are finished working with the instance, remove the above lines from the config file.  Otherwise, you are leaving the database open potential undesired access.

# Installing MariaDB client on RHEL

Reference: [Installing MariaDB with yum](https://mariadb.com/kb/en/library/yum/).

Sample `.repo` file:
```
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3.6/rhel74-amd64/
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
enabled=1
```
To install the MariaDB client:
```
yum install -y MariaDB-client
```
After the install a simple check:
```
mysql --version
```

# Working with ICP MariaDB from the command line

If you want to explore the ICP MariaDB instance using the command line, you need to install the MariaDB client.

A collection of "helper functions" is available in the repo in `src/mariadb-backup/#.#/helper-functions.sh`, where `#.#` is a version number, e.g., `1.0`.

Once you `source` the `helper-functions.sh` you can use them directly from your shell.

Two functions that are useful for getting connected to the ICP MariaDB instance:
```
mariadb_user=$(getMariaDBUser)
mariadb_password=$(getMariaDBPassword)
```

The above functions assume you have a valid `kubectl` login configuration.

Once you have the user and password for the instance you can open the `mysql` shell from an ICP master node with:
```
mysql --user=$mariadb_user --password=$mariadb_password
```

Add the `--host=<master_node>` option if you want to access the MariaDB instance on the given `<master_node>` remotely.

*NOTE:* For testing and exploratory purposes we changed the MariaDB instance configuration to allow the `mysql` client to use `tcp` as described earlier in this document.  

Reference: [mysql - The MySQl Command-Line Tool](https://dev.mysql.com/doc/refman/8.0/en/mysql.html)

# Building the MariaDB backup and restore Docker image.

It is assumed you have cloned the `https://github.com/ibm-cloud-architecture/icp-backupicp-backup` GitHub repository on some machine that is not necessarily part of the ICP cluster, e.g., a `boot` machine used for installing ICP on a collection of machines; or an administrator's desktop/laptop.

- From the `icp-backup/src/mariadb-backup` directory (note the final `.` in the command below):
```
docker build -f Dockerfile-1.0 --build-arg version=1.0 -t ibmcase/icp-mariadb-backup .
```

- Now you can save the docker image in preparation for copying it to an ICP master node.
In the command example here, docker images are saved to an `images` directory in the users home directory.  The `0.1.0` image version number included in the archive file name is more-or-less arbitrary.
```
docker save ibmcase/icp-mariadb-backup | gzip > ~/images/icp-mariadb-backup-image-0.1.0.tgz
```

- At this point the image can be copied to an ICP master node using `scp`.

*NOTE:* You can use the `docker images` command to see the image in the local docker registry.

# Loading the MariaDB backup and restore Docker image

In this section it is assumed the MariaDB backup and restore Docker image has been built and saved as described above and copied to an `images` directory on an ICP master node, e.g., in the administrator's home directory.

- First load the image into the master node Docker registry.
```
docker load -i ~/images/icp-mariadb-backup-image-0.1.0.tgz
```

- Next, "tag" the image in preparation for "pushing" it to the ICP docker registry.
```
docker tag ibmcase/icp-mariadb-backup:latest mycluster.icp:8500/default/ibmcase/icp-mariadb-backup:latest
```

- Lastly push the image to the ICP docker registry.  (For an HA ICP deployment, the ICP docker registry is persisted to shared storage so that all master nodes see the same registry.)
```
docker push mycluster.icp:8500/default/ibmcase/icp-mariadb-backup:latest
```

Again, you can check out the presence of the image in the local docker registry using the `docker images` command.

# Running the MariaDB backup and restore jobs

In the `resources` directory of the `icp-backup` repo are `yaml` files:
- `icp-mariadb-backup-pvc.yaml` - creates a persistent volume claim named `mariadb-backp-pvc` to use for shared storage access for the backup and restore jobs.  This only needs to be run once.
- `icp-mariadb-backup-job.yaml` - Runs a backup of all ICP MariaDB databases stored to the shared storage in `/data/backups`. The `mariadb-backup-pvc` must be created for this to run.
- `icp-mariadb-restore-job.yaml` - Runs a restore of all ICP MariaDB databases from `/data/backups` using the `mariadb-backup-pvc`.

You can modify the command parameters as desired in the backup and restore yaml.  For the restore in particular, you may want to only restore the `OAuthDBSchema` database, which you can specify using the `--dbnames` option to the `mariadb-restore.sh` script.

- Create the `mariadb-backup-pvc`  (The `default` storage class is used.)
```
kubectl create -f mariadb-backup-pvc.yaml
```

- Run the MariaDB backup
```
kubectl create -f icp-mariadb-backup-job.yaml
```

- To check on the job use: `kubectl get jobs`
- To check on the pod that runs the job: `kubectl get pods -a` or `kubectl get pods --show-all`. The job takes only seconds to complete so the pod should be in the completed state relatively quickly.
- To view the backup log:
```
kubectl logs pod/icp-mariadb-backup-xxxxx   # where xxxxx is the pod name uniqueifier
```

Here is a sample ICP MariaDB backup log:
```
[2018/04/22-20:54:14] mariadb-backup.sh(102) BEGIN mariadb-backup.sh
[2018/04/22-20:54:14] mariadb-backup.sh(149) Backup directory will be created in: /data/backups
[2018/04/22-20:54:14] mariadb-backup.sh(154) MariaDB host: mariadb.kube-system
[2018/04/22-20:54:15] mariadb-backup.sh(197) Databases to be backed up: OAuthDBSchema information_schema mysql performance_schema
[2018/04/22-20:54:15] mariadb-backup.sh(203) Creating backup directory: /data/backups/icp-mariadb-backup-2018-04-22-20-54-15
[2018/04/22-20:54:15] mariadb-backup.sh(210) Backups will be written to: /data/backups/icp-mariadb-backup-2018-04-22-20-54-15
[2018/04/22-20:54:16] mariadb-backup.sh(220) MariaDB user: root
[2018/04/22-20:54:16] mariadb-backup.sh(230) Backing up OAuthDBSchema to /data/backups/icp-mariadb-backup-2018-04-22-20-54-15/OAuthDBSchema-backup.sql...
[2018/04/22-20:54:16] mariadb-backup.sh(232) OAuthDBSchema back-up completed.
[2018/04/22-20:54:16] mariadb-backup.sh(230) Backing up information_schema to /data/backups/icp-mariadb-backup-2018-04-22-20-54-15/information_schema-backup.sql...
[2018/04/22-20:54:19] mariadb-backup.sh(232) information_schema back-up completed.
[2018/04/22-20:54:19] mariadb-backup.sh(230) Backing up mysql to /data/backups/icp-mariadb-backup-2018-04-22-20-54-15/mysql-backup.sql...
[2018/04/22-20:54:19] mariadb-backup.sh(232) mysql back-up completed.
[2018/04/22-20:54:19] mariadb-backup.sh(230) Backing up performance_schema to /data/backups/icp-mariadb-backup-2018-04-22-20-54-15/performance_schema-backup.sql...
[2018/04/22-20:54:20] mariadb-backup.sh(232) performance_schema back-up completed.
[2018/04/22-20:54:20] mariadb-backup.sh(235) END mariadb-backup.sh
```

- To run a restore job:
```
kubectl create -f icp-mariadb-restore-job.yaml
```

The restore yaml uses `--backup-home /data/backups`.  And by default the script with use the most recent backup directory in the backup home directory.

- To view the log from the restore:
```
kubectl logs pod/icp-mariadb-restore-xxxxx   # Where xxxxx is the pod name uniqueifier
```

A sample restore log file:
```
[2018/04/23-13:09:52] mariadb-restore.sh(110) BEGIN mariadb-restore.sh
[2018/04/23-13:09:52] mariadb-restore.sh(159) Most recent backup directory in /data/backups will be used for the MariaDB database restore.
[2018/04/23-13:09:52] mariadb-restore.sh(174) Backup directory path: /data/backups/icp-mariadb-backup-2018-04-22-20-54-15
[2018/04/23-13:09:52] mariadb-restore.sh(192) ICP MariaDB database backups for: "OAuthDBSchema information_schema mysql performance_schema" in: /data/backups/icp-mariadb-backup-2018-04-22-20-54-15
[2018/04/23-13:09:52] mariadb-restore.sh(198) MariaDB host: mariadb.kube-system
[2018/04/23-13:09:52] mariadb-restore.sh(223) Databases to be restored: OAuthDBSchema
[2018/04/23-13:09:52] mariadb-restore.sh(224) Backups will be restored from: /data/backups/icp-mariadb-backup-2018-04-22-20-54-15
[2018/04/23-13:09:52] mariadb-restore.sh(231) MariaDB user: root
[2018/04/23-13:09:53] mariadb-restore.sh(249) Database OAuthDBSchema does not currently exist in the MariaDB instance, creating OAuthDBSchema...
[2018/04/23-13:09:53] mariadb-restore.sh(256) Database OAuthDBSchema created.
[2018/04/23-13:09:53] mariadb-restore.sh(259) Restoring OAuthDBSchema from /data/backups/icp-mariadb-backup-2018-04-22-20-54-15/OAuthDBSchema-backup.sql...
[2018/04/23-13:09:53] mariadb-restore.sh(265) OAuthDBSchema restore completed.
[2018/04/23-13:09:53] mariadb-restore.sh(270) END mariadb-restore.sh
```

In the above sample only the `OAuthDBSchema` database was restored.  The yaml was set to use `--dbnames OAuthDBSchema` for the restore.

# Usage information for MariaDB backup and restore scripts.

- Use `mariadb-backup.sh --help`
```
Usage: mariadb-backup.sh [options]
   --dbhost <hostname|ip_address>   - (optional) Service name, host name or IP address of the
                                      ICP MariaDB service provider. For example, one of the
                                      ICP master nodes.
                                      Defaults to mariadb.kube-system.

   --backup-home <path>             - (optional) Full path to a backups home directory.
                                      Defaults to backups in the current working directory.

   --dbnames <name_list>            - (optional) Space separated list of database names to back up.
                                      The dbnames list needs to be quoted.
                                      Defaults to all databases defined in the MariDB instance.

   --exclude <name_list>            - (optional) Space separated list of database names to exclude
                                      from the backup.  The name list needs to be quoted.

   --help|-h                        - emit this usage information

 - and -- are accepted as keyword argument indicators

Sample invocations:
  ./mariadb-backup.sh
  ./mariadb-backup.sh --dbhost master01.xxx.yyy --backup-home /backups

 User is assumed to have write permission on backup home directory.
 User is assumed to have a current kubernetes context with admin credentials.

```

- Use `mariadb-restore.sh --help`
```
Usage: mariadb-restore.sh [options]
   --dbhost <hostname|ip_address>   - (optional) Service name, host name or IP address of the
                                      ICP MariaDB service provider. For example, one of the
                                      ICP master nodes.
                                      Defaults to mariadb.kube-system.

   --backup-home <path>             - (optional) Full path to a backups home directory.
                                      Defaults to backups in current working directory.

   --backup-dir <path>              - (optional) Path to a backup directory.
                                      Defaults to the most recent backup directory in the backup home directory.
                                      A valid backup directory will have a time stamp in its name and
                                      a file named dbnames.sh that is executable along with the backup
                                      JSON files and backup log files.

   --dbnames <name_list>            - (optional) Space separated list of database names to restore.
                                      The dbnames list needs to be quoted.
                                      Defaults to all databases with backup files in the given backup directory.

   --help|-h                        - emit this usage information

 - and -- are accepted as keyword argument indicators

Sample invocations:
  ./mariadb-restore.sh --backup-home /data/backups
  ./mariadb-restore.sh --dbhost master01.xxx.yyy --backup-dir ./backups/icp-mariadb-backup-2018-03-10-21-08-41

 User is assumed to have read permission on backup home directory.
 User is assumed to have a valid kubernetes context with admin credentials.
```
