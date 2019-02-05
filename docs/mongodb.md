# Backup and Restore the MongoDB Database in IBM Cloud Private (2.1.0.3 and Newer)

# THIS PAGE IS STILL UNDER CONTRUCTION. WE WILL UPDATE THESE STEPS SOON

IBM MongoDB datastore is used by IBM Cloud Private(ICP) to store information for OIDC service, metering service (IBM® Cloud Product Insights), Helm repository server, and Helm API server and more.  It runs as a Kubernetes statefulset **icp-mongodb** on the Master Nodes.  If you inspect your cluster you will notice the pods in this statefulset named **icp-mongodb-(increment)** that run one per each master and  mount storage to local host path.  The StatefulSet is exposed as a service as “mongodb”. 


## Topic Overview

In this topic, we describe how to perform a backup and restore on this MongoDB in IBM Cloud Private.  You may also use these techniques to take a backup on another MongoDB instance running in your cluster. The steps included are as follows:

* (Optional) Load data into the sample MongoDB
* Perform a MongoDB backup
* (Optional) Simulate data loss
* Restore a MongoDB database
* Perform data Validation

### (Optional) Load data into the sample MongoDB

Load some data into this database.  First run the following command to connect:
```kubectl run mongodb-mongodb-client --rm --tty -i --image bitnami/mongodb --command -- mongo --host mongodb-mongodb -p password```

You will be directed to the MongoDB CLI prompt. Run the following commands to load some data:
```
db.myCollection.insertOne ( { key1: "value1" });
db.myCollection.insertOne ( { key2: "value2" });
```

Next, run the following command to retrieve the values:  `db.myCollection.find()`

## Backup MongoDB
MongoDB provides a tool that we will leverage for backup called **mongodump**.  First, we need to create a Persistent Volume Claim, by running the following command:

```
kubectl apply -f https://raw.githubusercontent.com/patrocinio/mongodb/master/deploy/mongodump_pvc.yaml
```

Run the following command to dump the MongoDB database:

```
kubectl apply -f https://raw.githubusercontent.com/patrocinio/mongodb/master/deploy/mongodump_job.yaml
```

This Kubernetes job will dump the MongoDB databases into the persistent volume created above.  If this is your ICP cluster backup, make certain this PV is being backed up and saved.  You will need the contents to perform a restore at a future date.

## (Optional) Simulate data loss in MongoDB
For proving out your technique, simulate some data loss in MongoDB by deleting the data inserted from the optional step previously described.  Exec into your MongoDB pod.  Run the following command to delete one key:
```db.myCollection.deleteOne ({ key1: "value1" });```

If you run:  `db.myCollection.find()` you will see there is a single document in the collection.

## Restore the MongoDB Database

To restore the MongoDB database, run the following command:
```kubectl apply -f mongorestore_job.yaml```

> It is a good practice to now validate the data has been restored.  Rehearse the process with an optional standalone instance.

From **within** in the MongoDB CLI Pod, run the following command:  `db.myCollection.find()`

You should see either your ICP data or the optional sample data.
