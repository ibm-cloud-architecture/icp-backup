# Back up etcd

Now we are ready to back up the etcd data.

Now run the following command:

```
./backupEtcd.sh
```

You should see the following output:

```
root@eduardo-icp:~/icp-backup/scripts# ./backupEtcd.sh
Current Time : 2018.05.28-17.47.38
Back up to the following file:  /data/etcd.2018.05.28-17.47.38.db
Snapshot saved at /data/etcd.2018.05.28-17.47.38.db
```

This command generates a file in the master node `/tmp` directory, using the current timestamp.

Now copy this file (`/tmp/etcd.2018.05.28-17.47.38.db`) to a safe location, outside this node.
