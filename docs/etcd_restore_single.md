## Restore etcd


We are now ready to test the restoration of etcd.

Let's say that you recovered the initial environment as described in the procedure [Backup and restore the entire environment](entire.md).

We can now restore the data on the top of the environment.

### Etcd restore on single master ICP configuration

#### Stop etcd Pod

Before we can restore the data, we need to stop the etcd Pod. Run the following command:

```
mkdir -p /etc/cfc/podbackup
mv /etc/cfc/pods/etcd.json /etc/cfc/podbackup/
```

You can see the Pod has stopped by running the following command:

```
docker ps | grep etc
```

You should see any empty response

#### Purge etcd data

Next, we need to purge the current etcd data.

Run the following command:

```
rm -rf /var/lib/etcd
```

#### Load snapshot data

Assuming you have the file `/tmp/etcd.db` in your environment, containing a backup of your etcd, run the following procedure to restore etcd:

```
etcdctl3 snapshot restore /data/etcd.db \
--name=etcd0 --data-dir=/var/lib/etcd/restored \
--initial-advertise-peer-urls=https://${endpoint}:2380 \
--initial-cluster-token=etcd-cluster-1 \
--initial-cluster=etcd0=https://${endpoint}:2380
```

You should see the following response:

```
root@icp-master:/etc/cfc/pods# etcdctl3 snapshot restore /data/etcd.db \
> --name=etcd0 --data-dir=/var/lib/etcd/restored \
> --initial-advertise-peer-urls=https://${endpoint}:2380 \
> --initial-cluster-token=etcd-cluster-1 \
> --initial-cluster=etcd0=https://${endpoint}:2380
2018-02-28 19:10:55.602343 I | mvcc: restore compact to 171204
2018-02-28 19:10:55.614782 I | etcdserver/membership: added member 13d542895c43caf2 [https://10.0.0.1:2380] to cluster f2f6638141c39fb3

```

The command above loads the data to directory `/var/lib/etcd/restored`.

#### Move the data to the right directory


We need now to move to expected directory, by running the following commands:

```
mv /var/lib/etcd/restored/* /var/lib/etcd/
rmdir /var/lib/etcd/restored
```

#### Re-enable etcd Pod

we can re-enable the etcd Pod. Run the following command:

```
mv /etc/cfc/podbackup/etcd.json /etc/cfc/pods/
```

It will take a few seconds for etcd to come back. You can see the progress by running the following command:

```
docker ps | grep etcd
```

Eventually (it might take a few minutes), you should see a response like this:

```
root@icp-master:~# docker ps | grep etcd
999c8e48c0e3        ibmcom/etcd                        "etcd --name=etcd0 -…"   About a minute ago   Up About a minute                       k8s_etcd_k8s-etcd-10.0.0.1_kube-system_349da84ef01d46f51daacdd97b2991e1_0
747287ff5b4f        ibmcom/pause:3.0                   "/pause"                 About a minute ago   Up About a minute                       k8s_POD_k8s-etcd-10.0.0.1_kube-system_349da84ef01d46f51daacdd97b2991e1_0

```

### Validate the configuration

Now, let's validate that the new environment has the data restored in etcd.

Run the following command:

```
kubectl get configmaps | grep snake
```

You should see a response, showing many ConfigMaps:

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
