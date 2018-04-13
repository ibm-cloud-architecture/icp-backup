# Back up etcd

Now we are ready to back up the etcd data.

Now run the following command:

```
etcdctl3 snapshot save /data/etcd.db
```

You should see the following output:

```
root@icp-master:~/icp-backup/scripts# etcdctl3 snapshot save /data/etcd.db
2018-02-28 18:32:55.691445 I | warning: ignoring ServerName for user-provided CA for backwards compatibility is deprecated
Snapshot saved at /data/etcd.db
```

Now the file is available in the master node `/tmp` directory

Now copy this file (`/tmp/etcd.db`) to a safe location, outside this node.
