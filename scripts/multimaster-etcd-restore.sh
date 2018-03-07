#!/bin/bash
data_dir="/var/lib/etcd"
restore_dir="/var/lib/etcd/restored"


## Get etcd docker image details
etcd_image=$(jq -r '.spec.containers[].image'  /etc/cfc/podbackup/etcd.json)
volume_mounts="-v /tmp:/data -v /etc/cfc/conf/etcd:/certs -v /var/lib/etcd:/var/lib/etcd"
self=$(jq -r '.spec.containers[].command[] | select(contains("advertise-client-urls="))'  /etc/cfc/podbackup/etcd.json | cut -d= -f2)
etcdctl3="docker run --entrypoint=etcdctl -e ETCDCTL_API=3 ${volume_mounts} ${etcd_image} --cert /certs/client.pem --key /certs/client-key.pem --cacert /certs/ca.pem --endpoints ${self}"
etcdctl2="docker run --entrypoint=etcdctl ${volume_mounts} ${etcd_image} --cert /certs/client.pem --key /certs/client-key.pem --cacert /certs/ca.pem --endpoints ${self}"

## Get etcd cluster settings
node_name=$(jq -r '.spec.containers[].command[] | select(contains("name="))'  /etc/cfc/podbackup/etcd.json)
initial_advertise_peer_urls=$(jq -r '.spec.containers[].command[] | select(contains("initial-advertise-peer-urls="))'  /etc/cfc/podbackup/etcd.json)
initial_cluster=$(jq -r '.spec.containers[].command[] | select(contains("initial-cluster="))'  /etc/cfc/podbackup/etcd.json)
initial_cluster_token=$(jq -r '.spec.containers[].command[] | select(contains("initial-cluster-token="))'  /etc/cfc/podbackup/etcd.json)


## Run the restore on the node
$etcdctl3 snapshot restore /data/snapshot.db \
--data-dir=$restore_dir \
$node_name \
$initial_advertise_peer_urls \
$initial_cluster_token \
$initial_cluster

if [[ "$?" == "0" ]]
then
  echo "Restore successful"
else
  echo "Restore failed"
fi
