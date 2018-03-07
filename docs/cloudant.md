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

Now let's simulate a loss of the Docker Registry. To do so, just delete the under `/opt/ibm/cfc/cloudant` from every master nodes:

```
  rm -rf /opt/ibm/cfc/cloudant
```

It's recommended to use some automated script such as ansible scripts to delete all directories at the same time.
Here is an [sample ansible script to delete the folders](../scripts/move_cloundant_on_masters.yml)


## Restore your ICP Cloudant database

To restore the Cloudant DB, follow the below steps:
(You need to have the couchbackup and couchrestore utility installed as mentioned above)


1. Expose the target ICP Cloudant DB as NodePort service (or deploy the restore utility as kubernetes job)

2. Move the backup source file to the target Environment

3. Restore the database:
```
  couchrestore --url "http://admin:orange@172.16.40.2:31890" --db "platform-db" < platform-db-backup.txt
  couchrestore --url "http://admin:orange@172.16.40.2:31890" --db "security-data-db" < security-data-backup.txt
```

Where the port 31890 is the NodePort maps to the Cloudant endpoint of 5984.
