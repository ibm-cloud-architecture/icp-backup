## Restoring etcd For Single

Follow the instructions here to restore your etcd datastore to one of the Master Nodes.

> Note these instructions do not yet include the process for restoring etcd for topologies that have externalized the etcd cluster.  However, you can derive both the backup and restore processes from the tools and steps followed here. Use the same principles for both backup and recovery.  As with other scenarios rehearsing the process is required.  We currently have this scenario in our backlog and invite contributors.

It is assumed you are using the restore process for one of the following reasons:

* You have recovered the initial environment as described in the procedure [Backup and restore the entire environment](entire.md) because you no longer have a Master Node with a clean state.
* You are recovering a Master Node for a single Master Node cluster
* You are recovering a Master Node in a multi-Master Node environment that requires you to manually restore the initial state etcd (to accommodate your backup tool strategy / methodology)

### Etcd Restore on Single Master ICP Topology

Before restoring etcd, we need to stop the etcd Pod using the following command:

```
mkdir -p /etc/cfc/podbackup
mv /etc/cfc/pods/etcd.json /etc/cfc/podbackup/
```

Verify the pod has indeed stopped by running the following command:  `docker ps | grep etc`

If the pod has successfully been stopped you will see nothing returned.

Next, we need to purge the current etcd data by running the following command:  `rm -rf /var/lib/etcd /var/lib/etcd-wal/wal`

Using your backup file `/tmp/etcd.your-date-and-time.db` from your clusters earlier backup run the following procedure to restore etcd:  `./restoreEtcd.sh etcd.your-date-and-time.db`

You should see the following response:

```
root@eduardo-icp:~/icp-backup/scripts# ./restoreEtcd.sh etcd.your-date-and-time.db
Restore snapshot etcd.your-date-and-time.db
your-date-and-time I | mvcc: restore compact to **your size value here**
your-date-and-time I | etcdserver/membership: added member **the ID for the memeber** [https://169.61.93.24:2380] to cluster **your cluster id**```
```

The command above loads the data to directory `/var/lib/etcd/restored`.

Next you must move the data to the expected directory by running the following commands:
```
mv /var/lib/etcd/restored/* /var/lib/etcd/
mv /var/lib/etcd/member/wal /var/lib/etcd-wal/wal
rmdir /var/lib/etcd/restored
```

After successfully performing the previous steps you are ready to once again enable the etcd pod.  Do so by running the following command:  `mv /etc/cfc/podbackup/etcd.json /etc/cfc/pods/`

Depending on your environment it will likely take a few seconds (to a few minutes) for etcd to become live. You can see the progress by running the following command: `docker ps | grep`


Eventually (it might take a few minutes), you should see a response similar to the following:
```
root@icp-master:~# docker ps | grep etcd
999c8e48c0e3        ibmcom/etcd                        "etcd --name=etcd0 -…"   About a minute ago   Up About a minute                       k8s_etcd_k8s-etcd-10.0.0.1_kube-system_349da84ef01d46f51daacdd97b2991e1_0
747287ff5b4f        ibmcom/pause:3.0                   "/pause"                 About a minute ago   Up About a minute                       k8s_POD_k8s-etcd-10.0.0.1_kube-system_349da84ef01d46f51daacdd97b2991e1_0
```

Next let's validate that the new environment has the data restored in etcd.  Run the following command to display the ConfigMaps from Kubernetes:  `kubectl get configmaps | grep snake`

If you loaded our sample before starting the exercise you will see the below listing.  If you did not, you **should** see whichever ConfigMaps were part of your system upon the time your backup was taken.

```
root@icp-master:~# kubectl get configmaps | grep snake
snake-10        1         48m
snake-11        1         48m
snake-12        1         48m
snake-13        1         48m
snake-14        1         48m
snake-15        1         48m
snake-16        1         48m
snake-17        1         48m
snake-18        1         48m
snake-19        1         48m
snake-20        1         48m
snake-21        1         48m
snake-22        1         48m
snake-23        1         48m
snake-24        1         48m
snake-25        1         48m
snake-26        1         48m
snake-8         1         48m
snake-9         1         48m
```

Congratulations! You restored successfully your etcd!
