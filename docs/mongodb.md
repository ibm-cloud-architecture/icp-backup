# Backup and Restore the MongoDB Database in IBM Cloud Private (2.1.0.3 and Newer)

IBM MongoDB datastore is used by IBM Cloud Private(ICP) to store information for OIDC service, metering service (IBM® Cloud Product Insights), Helm repository server, and Helm API server and more.  It runs as a Kubernetes statefulset **icp-mongodb** on the Master Nodes.  If you inspect your cluster you will notice the pods in this statefulset named **icp-mongodb-(increment)** that run one per each master and  mount storage to local host path.  The StatefulSet is exposed as a service as “mongodb”. 


## Topic Overview

In this topic, we describe how to perform a backup and restore on this MongoDB instance in IBM Cloud Private.  You may also use these techniques to take a backup any MongoDB instance running in your cluster. The steps included are as follows:

* (Optional) Load data into the sample MongoDB
* Perform a MongoDB backup
* (Optional) Simulate data loss
* Restore a MongoDB database
* Perform data Validation

Before going forward please NOTE: If using an ICP version prior to 3.1.1 `--sslCAFile /data/configdb/tls.crt` should be `--sslCAFile /ca/tls.crt` when using `mongo` `mongodump` or `mongorestore` commands.
### (Optional) Load data into the sample MongoDB

Load some data into this database.  First run the following command to connect:

```kubectl exec -n kube-system -it icp-mongodb-0 -- sh -c 'mongo --host rs0/mongodb:27017 --username $ADMIN_USER --password $ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /data/configdb/tls.crt --sslPEMKeyFile /work-dir/mongo.pem'```

You will be directed to the MongoDB CLI prompt. Run the following commands to load some data:
```
db.myCollection.insertOne({ key1: "value1" });
db.myCollection.insertOne({ key2: "value2" });
```

Next, run the following command to retrieve the values:  

`db.myCollection.find()`

## Backup MongoDB
MongoDB provides a tool that we will leverage for backup called **mongodump**.  

Backup data can be dumped to a persistent volume or to  local filesystem of the master node. 

### Dump backup onto local filesystem

Run the following command to dump to the master node's filesystem. This will create a dump of all the databases at  /var/lib/icp/mongodb/work-dir/backup/mongodump. 

```kubectl -n kube-system exec icp-mongodb-0 -- sh -c 'mkdir -p /work-dir/Backup/mongodump; mongodump --oplog --out /work-dir/Backup/mongodump --host rs0/mongodb:27017 --username $ADMIN_USER --password $ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /data/configdb/tls.crt --sslPEMKeyFile /work-dir/mongo.pem' ```

Backup data can then be archived with a timestamp and moved elsewhere.

### Dump backup onto a Persistent Volume

Run the following commands to dump to a PV. The *mongodump-pv.yaml*, *mongodump-pvc.yaml*, *icp-mongodb-mongodump-job.yaml*, and *icp-mongodb-mongorestore-job.yaml* files can be found in `icp-backup/resources` of this repository.

First, we need to create a PV. If you are going this route, you should consult kubernetes doc on how to create the PV you are looking for. https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistent-volumes

For this example, we already created an NFS directory and added the nfs server ip and directory to the `mongodump-pv.yaml`. We will create our PV with the following command:

```
kubectl apply -f mongodump-pv.yaml
```

We then need to create a Persistent Volume Claim, which our Jobs can use to get access to the PV, by running the following command:


```
kubectl apply -f mongodump-pvc.yaml
```

Run the following command to dump the MongoDB database:

```
kubectl apply -f icp-mongodb-mongodump-job.yaml
```

This Kubernetes job will dump the MongoDB databases into the persistent volume created above.  If this is your ICP cluster backup, make certain this PV is being secured, backed up, and saved.  You will need the contents to perform a restore at a future date.

## (Optional) Simulate data loss in MongoDB
For proving out your technique, simulate some data loss in MongoDB by deleting the data inserted from the optional step previously described.  Exec into your MongoDB pod.  Run the following commands to delete one key:

```kubectl exec -n kube-system -it icp-mongodb-0 -- sh -c 'mongo --host rs0/mongodb:27017 --username $ADMIN_USER --password $ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /data/configdb/tls.crt --sslPEMKeyFile /work-dir/mongo.pem'```

```db.myCollection.deleteOne ({ key1: "value1" });```

If you run:  `db.myCollection.find()` you will see there is a single document in the collection.

## Restore the MongoDB Database

### Restore backup from local filesystem

In the dump instructions, you dumped the mongoDB database into /var/lib/icp/mongodb/work-dir/backup/mongodump and presumably archived and moved it else where. To restore it, you need to move that archive back into /var/lib/icp/mongodb/work-dir/backup/mongodump, unarchive it and run the mongorestore command. 

Run the following to restore data saved to the master node's filesystem:

```kubectl -n kube-system exec icp-mongodb-0 -- sh -c 'mongorestore --host rs0/mongodb:27017 --username $ADMIN_USER --password $ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /data/configdb/tls.crt --sslPEMKeyFile /work-dir/mongo.pem /work-dir/Backup/mongodump'```

### Restore backup from a Persistent Volume

Run the following to restore data saved to a persistent volume.

To restore the MongoDB database, run the following command:
```kubectl apply -f icp-mongodb-mongorestore-job.yaml```

## (Optional) Validate the data has been restored

From **within** in the MongoDB CLI Pod, run the following commands:

```kubectl exec -n kube-system -it icp-mongodb-0 -- sh -c 'mongo --host rs0/mongodb:27017 --username $ADMIN_USER --password $ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /data/configdb/tls.crt --sslPEMKeyFile /work-dir/mongo.pem'```

`db.myCollection.find()`

You should see the both key value pairs.
