echo Restore snapshot $1

. ./etcd.sh
$etcdctl3 snapshot restore /data/$1 \
--name=etcd0 --data-dir=/var/lib/etcd/restored \
--initial-advertise-peer-urls=https://${endpoint}:2380 \
--initial-cluster-token=etcd-cluster-1 \
--initial-cluster=etcd0=https://${endpoint}:2380