# Restore etcd for Multi-Master Node ICP Topology

In a multi master ICP environment you'll need to first restore a consistent cluster.  This can either be done via restoring a single node, and then growing the cluster out to the desired size, or by restoring the entire cluster from the same backup copy all at once. In this topic we will describe how to perform the full cluster restore.

To reduce the effort required we will use ansible where possible to execute commands on all master nodes simultaneously.  It is assumed that the ansible commands are run from the boot node (normally master1) which holds the cluster configuration files from the initial installation. The configuration files are typically held in `/opt/ibm/cluster`. Adjust commands accordingly if your installation uses a different directory.

Define the following environment variable, according to your installation:  `export CLUSTER_DIR=/opt/ibm/cluster`

## Prerequisites Ansible and jq

Ensure that Ansible is installed on the boot node:  `which ansible`  If this command returns an empty response, install ansible on this node.

All Master Nodes also require the `jq` json parsing tool. For instance on Ubuntu, you can ensure this tool is installed with the following command:
```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m package -a "use=apt name=jq state=present"
```

## Stop Kubernetes on ALL Master Nodes

Before restoring the data, we need to stop the etcd Pod. To ensure cluster consistency we will also shut down all other pods managed by hyperkube. In most deployments (ones where we have separate management servers) we also need to shut these down.
```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -a "mkdir -p /etc/cfc/podbackup"

ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "mv /etc/cfc/pods/*.json /etc/cfc/podbackup"
```

Wait for etcd to be shut down on **all** nodes:
```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m wait_for -a  "port=4001 state=stopped"
```

Once etcd has stopped, we will shut down kubelet running this command on all Master (and Management) nodes:

```
ansible master,management -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m service -a "name=kubelet state=stopped"
```

Once kubelet has stopped, restart the docker service to ensure all pods not managed by kubelet are shut down.
```
ansible master,management -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m service -a "name=docker state=restarted"
```


## Purge, Copy and Restore etcd Data

Next, **purge** the current etcd data on all Master Nodes:
```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "rm -rf /var/lib/etcd"
```

Copy etcd snapshot to all Master Nodes.  Assuming you have the file `/tmp/etcd.your-date-and-time.db` in your environment, containing a backup of your etcd, run the following procedure to copy the file to all master nodes:
```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m copy -a "src=/tmp/etcd.your-date-and-time.db dest=/tmp/snapshot.db"
```

Following the purge, restore the snapshot on all Master Nodes.  Assuming you have cloned the git repo, and your current directory is located in `icp-backup/scripts`, run the following command:
```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m script -a "./multimaster-etcd-restore.sh"
```

The command above loads the data to directory /var/lib/etcd/restored on each of your Master Nodes, with the cluster settings configured.  Assuming this command was successful, we need now to move to expected directory, by running the following commands:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "mv /var/lib/etcd/restored/* /var/lib/etcd/"
```

Before we re-enable kubelet and etcd with the newly restored data, we will purge kubelet pods directory to ensure consistency between the cached kubelet data and the etcd data.  We use a simple script to ensure that all docker mounts are unmounted before purging the pods directory.  In deployments where we have management nodes, we'll also need to run the following:

```
ansible master,management -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m script -a "./purge_kubelet_pods.sh"
```
Finally, re-enable both **kubelet** and the **etcd** pod.

With the etcd cluster data restored, we can re-enable kubelet and instruct it to start the etcd cluster.  Run the following commands:

```
ansible master,management -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m service -a "name=kubelet state=started"

ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "mv /etc/cfc/podbackup/etcd.json /etc/cfc/pods"
```

It will take a few seconds for etcd to come back. We can use ansible to monitor the progess:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m wait_for -a  "port=4001 state=started"
```

## Validate etcd Cluster Health

To setup the etcdctl tool to query the etcd cluster, run the following commands, adjusting the IP address for the current node you're working on:  `export endpoint=<master-node-ip>``

Then run the following scripts:  `. ./etcd.sh`

To query the cluster health, run this command:  `etcdctl2 cluster-health`

You should see a response similar to the following:

```
member 8211f1d0f64f3269 is healthy: got healthy result from https://10.0.0.1:2380
member 91bc3c398fb3c146 is healthy: got healthy result from https://10.0.0.2:2380
member fd422379fda50e48 is healthy: got healthy result from https://10.0.0.3:2380
cluster is healthy
```

#### Start the Remaining ICP Cluster Pods

Now that etcd is restored to a healthy state, let **kubelet** start the rest of the core kubernetes pods, which in turn will start the workloads managed by kubernetes.
```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "mv /etc/cfc/podbackup/*.json /etc/cfc/pods"
```

It will likely take several minutes for all pods to be restarted.  Monitor the pods in the `kube-system` namespace by running: `kubectl get pods --namespace=kube-system`

# Validating the Results

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
