# Backup and Restore etcd in IBM Cloud Private

The backup process is the same whether you're running single master or multi-Master configurations of ICP.  In both cases the backup is always taken from a single node, to ensure consistency upon restore.  In the case of restore to a multi-node cluster, any of the nodes may be restored from the same backup.

To back up and restore etcd, you must be logged into one of the Master Nodes.  Clone this GitHub repository to the Master Node, you will use it when performing the steps in this guide.

```
git clone https://github.com/ibm-cloud-architecture/icp-backup.git
cd icp-backup/scripts
```
Next define an environment variable **endpoint** that points to a node running etcd:

```
export endpoint=<master-node-ip>
```
If you are simply testing the backup and restore process it is useful to have data to verify the validity of your process.  Follow [Create some workloads in ICP](etcd_workload.md) to create a data-trail to follow.

## Backup Procedure for etcd

From the Master Node run the following command from the cloned GitHub repository above:

```
./backupEtcd.sh
```

If successful, you should receive output resembling the following:

```
root@eduardo-icp:~/icp-backup/scripts# ./backupEtcd.sh
Current Time : your-date-and-time.38
Back up to the following file:  /data/etcd.your-date-and-time.db
Snapshot saved at /data/etcd.your-date-and-timedb
```

This command generates a file (your backup) in the master node `/tmp` directory, using the current timestamp.  Copy this file (`/tmp/etcd.your-date-and-time.db`) to a safe location, outside the node and in a location that is subject to backup.  This backup should be kept in perpetuity (forever).

If you are ready to restore your datastore from this (or another) backup, proceed to the relevant topic:
* [Restore etcd on single master environment](etcd_restore_single.md)
* [Restore etcd on multi-master environment](etcd_restore_multi.md)
