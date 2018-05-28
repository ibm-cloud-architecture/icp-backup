export org=ibmcom
export repo=etcd
export tag=v3.2.14
#export endpoint=10.0.0.1
export etcdctl2="docker run --entrypoint=etcdctl -v /etc/cfc/conf/etcd:/certs -v /var/lib/etcd:/var/lib/etcd -v /tmp:/data $org/$repo:$tag --cert-file=/certs/client.pem --key-file=/certs/client-key.pem --ca-file=/certs/ca.pem --endpoints https://${endpoint}:4001"
export etcdctl3="docker run --entrypoint=etcdctl -e ETCDCTL_API=3 -v /tmp:/data -v /etc/cfc/conf/etcd:/certs -v /var/lib/etcd:/var/lib/etcd $org/$repo:$tag --cert /certs/client.pem --key /certs/client-key.pem --cacert /certs/ca.pem --endpoints https://${endpoint}:4001"