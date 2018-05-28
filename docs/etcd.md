# Backup and restore etcd in IBM Cloud Private

The backup process is the same, whether you're running single master or multi-master configurations of ICP.
In both cases the backup is always taken from a single node, to ensure consistency on restore.

In the case of restore to a multinode cluster, all nodes are restored from the same backup copy.

To back up and restore etcd, you need to be logged to a master node

After you connect to a master node, you need to clone this github repository:


```
git clone https://github.com/ibm-cloud-architecture/icp-backup.git
cd icp-backup/scripts
```

Then you need to define the environment variable endpoint to point to a master node:

```
export endpoint=<master-node-ip>
```

Follow these steps to back up and restore your etcd:

* [Create some workloads in ICP](etcd_workload.md)
* [Back up etcd](etcd_backup.md)
* [Restore etcd on single master environment](etcd_restore_single.md)
* [Restore etcd on multi-master environment](etcd_restore_multi.md)


