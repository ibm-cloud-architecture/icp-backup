# Backup and restore etcd in IBM Cloud Private

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

Then run the following scripts

```
. ./etcd.sh
```

You can validate the setup by running the following command:

```
etcdctl3
```

You should see the following message:

```
root@icp-master:~/icp-backup/scripts# etcdctl3
NAME:
	etcdctl - A simple command line client for etcd3.

USAGE:
	etcdctl

...
```

## Run some workloads in ICP

Before we back up etcd in ICP, let's load some data.
You can deploy any application or even crete some Kubernetes config maps.

The following script creates and deletes config maps continuosly:

```
./createConfigMaps.sh
```

If you leave this script running for a while, you will see many ConfigMaps created:

```
root@icp-master:~/icp-backup/scripts# kubectl get configmaps | grep snake
snake-0         1         9m
snake-1         1         9m
snake-2         1         9m
snake-3         1         9m
snake-4         1         9m
snake-85        1         9m
snake-86        1         9m
snake-87        1         9m
snake-88        1         9m
snake-89        1         9m
snake-90        1         9m
snake-91        1         9m
snake-92        1         9m
snake-93        1         9m
snake-94        1         9m
snake-95        1         9m
snake-96        1         9m
snake-97        1         9m
snake-98        1         9m
snake-99        1         9m
```

## Back up etcd

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

## Restore etcd

We are now ready to test the restoration of etcd.

Let's say that you recovered the initial environment as described in the procedure [Backup and restore the entire environment](entire.md).

We can now restore the data on the top of the environment.

### Stop etcd Pod

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

### Purge etcd data

Next, we need to purge the current etcd data.

Run the following command:

```
rm -rf /var/lib/etcd
```

### Load snapshot data

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

The command above loads the data to directory /var/lib/etcd/restored. 

### Move the data to the right directory


We need now to move to expected directory, by running the following commands:

```
mv /var/lib/etcd/restored/* /var/lib/etcd/
rmdir /var/lib/etcd/restored
```

### Re-enable etcd Pod

we can re-enable the etcd Pod. Run the following command:

```
mv /etc/cfc/podbackup/etcd.json /etc/cfc/pods/
```

It will take a few seconds for etcd to come back. You can see the progress by running the following command:

```
docker ps | grep etcd
```

Eventually, you should see a response like this:

```
root@icp-master:~# docker ps | grep etcd
999c8e48c0e3        ibmcom/etcd                        "etcd --name=etcd0 -…"   About a minute ago   Up About a minute                       k8s_etcd_k8s-etcd-10.0.0.1_kube-system_349da84ef01d46f51daacdd97b2991e1_0
747287ff5b4f        ibmcom/pause:3.0                   "/pause"                 About a minute ago   Up About a minute                       k8s_POD_k8s-etcd-10.0.0.1_kube-system_349da84ef01d46f51daacdd97b2991e1_0

```

## Validate the configuration

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





