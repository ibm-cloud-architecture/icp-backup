# Back up and restore the Cloudant database in IBM Cloud Private

IBM Cloudant local is used by IBM Cloud Private(ICP) to store information for OIDC service, metering service (IBM® Cloud Product Insights), Helm repository server, and Helm API server.
It runs as a kubernetes Statefulset and mount to local host path. The StatefulSet is exposed as HeadLess service as “cloudantdb”.
There are 2 databases holding the ICP metadata:

* platform-db
* security-data

In this page, we'll describe how to back up and restore the Cloudant local db in IBM Cloud Private.


## Backup the Cloudant Database

In an ICP HA environment, Cloudant DB runs in a cluster that spread across multiple ICP master nodes. The most reliable approach is to use the [Cloudant DB backup and restore facility](https://developer.ibm.com/clouddataservices/2016/03/22/simple-couchdb-and-cloudant-backup/).

Here are the steps you can follow:

1. Expose cloudantdb as a NodePort service
ICP packages the cloudantdb as a kubernetes headless service, we need to expose it as NodePort so that we can run backup utility from outside of ICP cluster.   
*NOTE: A better solution is to deploy a cloudant backup kubernetes job into the ICP that connects to the cloudantdb service, and perform dailly or scheduled backup.*

You can reference the [sample NodePort service definition file](../scripts/CloudantDBNodePort.yaml) to create your CloudantDB NodePort service, run the command to create the service:
```
  kubectl --namespace=kube-system apply -f CloudantDBNodePort.yaml
```
Note down the HTTP or HTTPs TCP port for the exposed Cloudant service (for example: HTTP 31890 for TCP port 5984)

2. Install couchdb backup utility

```
  npm install -g @cloudant/couchbackup
```

3. Find the cloudant database admin user name and password from ICP secret via ICP console or command line tool.

4. Backup the Cloudant DB with the following command:

```
  couchbackup --url "http://admin:orange@172.16.40.2:31890" --log backup.log --db "platform-db" > platform-db-backup.txt
  couchbackup --url "http://admin:orange@172.16.40.2:31890" --log backup.log --db "security-data" > security-data-backup.txt
```

Where the port 31890 is the NodePort maps to the Cloudant endpoint of 5984.

Keep the backup file in a safe place, you will need it to store in a DR or new site. 

## Simulate a loss of the ICP Cloudant database

Now let's simulate a loss of the Docker Registry. To do, just delete the files under /var/lib/registry:

```
rm -rf /var/lib/registry/*
```

Now if you open your browser to:

```
https://$MASTER_ID:8443/console/images
```

You will see an empty response.

### Restore your ICP Cloudant database

To restore your Docker Registry, bring back to file `/tmp/icp_dr.tar.gz` to directory `/tmp` and run the following commands:

```
cd /var/lib/registry
tar xvzf /tmp/icp_dr.tar.gz
```

Now run the following command to recycle the image manager Pod:

```
kubectl delete pod image-manager-0 -n kube-system
```

Now if you re-open the URL `https://$MASTER_ID:8443/console/images`, you shuld see the images restored.
