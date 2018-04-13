# Etcd restore on multi-master ICP configuration

In a multi master ICP environment you'll need to restore a consistent cluster.
This can either be done via restoring a single node, and then growing the cluster out to the desired size, or
you can restore the entire cluster from the same backup copy at the same time. In this section we will describe how to
perform the full cluster restore.

To reduce the effort required we will use ansible where possible to execute commands on all master nodes simultaneously.
It is assumed that the ansible commands are run from the boot node (normally master1) which holds the cluster configuration files from the
initial installation. The configuration files are typically held in `/opt/ibm/cluster`. Adjust commands accordingly if your installation used a different directory.

Define the following environment variable, according to your installation:

```
export CLUSTER_DIR=/opt/ibm/cluster
```

## Preprequisites

### Ansible

Ensure that Ansible is installed on the boot node.

```
which ansible
```

If this command returns an empty response, install ansible on this node.

### jq

All master nodes require the `jq` json parsing tool.
On Ubuntu, you can ensure this tool is installed with the following command:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m package -a "use=apt name=jq state=present"
```

## Stop Kubernetes on all nodes

Before we can restore the data, we need to stop the etcd Pod. To ensure cluster consistency we will also shut down all other pods managed by hyperkube.

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -a "mkdir -p /etc/cfc/podbackup"

ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "mv /etc/cfc/pods/*.json /etc/cfc/podbackup"

```

Wait for etcd to shut down on all nodes:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m wait_for -a  "port=4001 state=stopped"
```

Once etcd has stopped, we will shut down kubelet running this command on all master nodes:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m service -a "name=kubelet state=stopped"
```

Once kubelet has stopped, we will restart the docker service to ensure all pods not managed by kubelet is shut down.

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m service -a "name=docker state=restarted"
```


## Purge etcd data

Next, we need to purge the current etcd data on all master nodes.

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "rm -rf /var/lib/etcd"
```

## Copy etcd snapshot to all master nodes

Assuming you have the file `/tmp/etcd.db` in your environment, containing a backup of your etcd, run the following procedure to copy the file to all master nodes:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m copy -a "src=/tmp/etcd.db dest=/tmp/snapshot.db"
```

## Restore the snapshot on all master nodes

Assuming you have cloned the git repo, and are located in `icp-backup/scripts`, run the following command:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m script -a "./multimaster-etcd-restore.sh"
```

The command above loads the data to directory /var/lib/etcd/restored on all master nodes, with the cluster settings configured.


## Move the data to the right directory


We need now to move to expected directory, by running the following commands:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "mv /var/lib/etcd/restored/* /var/lib/etcd/"
```

## Purge kubelet pods data

Before we re-enable kubelet and etcd with the newly restored data, we will purge kubelet pods directory to ensure consistency between the cached kubelet data and the etcd data.
We will use a simple script to ensure that all docker mounts are unmounted before purging the pods directory.

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m script -a "./purge_kubelet_pods.sh"
```


## Re-enable kubelet and etcd Pod

Now that the etcd cluster data is restored, we can re-enable kubelet and instruct it to start the etcd cluster.
Run the following commands:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m service -a "name=kubelet state=started"

ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "mv /etc/cfc/podbackup/etcd.json /etc/cfc/pods"
```

It will take a few seconds for etcd to come back. We can use ansible to monitor the progess:

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m wait_for -a  "port=4001 state=started"
```

## Validate etcd cluster health

To setup the etcdctl tool to query the etcd cluster, run the following commands, adjusting the IP address for the current node you're working on

```
export endpoint=<master-node-ip>
```

Then run the following scripts

```
. ./etcd.sh
```

To query the cluster health, run this command:

```
etcdctl2 cluster-health
```

You should get a respons similar to this

```
member 8211f1d0f64f3269 is healthy: got healthy result from https://10.0.0.1:2380
member 91bc3c398fb3c146 is healthy: got healthy result from https://10.0.0.2:2380
member fd422379fda50e48 is healthy: got healthy result from https://10.0.0.3:2380
cluster is healthy
```

#### Start the rest of the ICP cluster pods

Now that etcd is restored to a healthy state, we can let kubelet start the rest of the core kubernetes pods, which in turn will
start the workloads managed by kubernetes.

```
ansible master -i $CLUSTER_DIR/hosts -e @$CLUSTER_DIR/config.yaml --private-key=$CLUSTER_DIR/ssh_key -m shell -a "mv /etc/cfc/podbackup/*.json /etc/cfc/pods"
```

You can expect it to take several minutes for all pods to be restarted.

You can monitor the pods in the `kube-system` namespace by running

```
kubectl get pods --namespace=kube-system
```

# Validate the configuration

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
