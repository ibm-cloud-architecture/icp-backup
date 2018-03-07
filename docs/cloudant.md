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

* Clone this github project:

```
git clone https://github.com/ibm-cloud-architecture/icp-backup.git
cd icp-backup
```

* Expose cloudantdb as a NodePort service
ICP packages the cloudantdb as a kubernetes headless service, we need to expose it as NodePort so that we can run backup utility from outside of ICP cluster.   

*NOTE: A better solution is to deploy a cloudant backup kubernetes job into the ICP that connects to the cloudantdb service, and perform dailly or scheduled backup.*

You can reference the [sample NodePort service definition file](../scripts/CloudantDBNodePort.yaml) to create your CloudantDB NodePort service, run the command to create the service, being in the directory `scripts`:

```
cd scripts
kubectl --namespace=kube-system apply -f CloudantDBNodePort.yaml
```

Now define the HTTP port for the exposed Cloudant service, by running the following command (for example: HTTP 31890 for Pod TCP port 5984):

```
kubectl --namespace=kube-system get svc cloudantdb-ext -o json

export PORT=<Node port associated with Pod port 5984>
```

* Install node, if it is not installed

Run the following command to install node:

```
apt install nodejs-legacy
```

* Install npm, if it is not installed

Run the following command to install npm:

```
apt install -y npm
```

* Install couchdb backup utility

```
  npm install -g @cloudant/couchbackup
```

* Switch the kube-system namespace:

```
kubectl config set-context mycluster.icp-context --user admin --namespace=kube-system
```

* Find the cloudant database admin user name and password from ICP secret, by running the following command:

```
kubectl get secret cloudant-credentials -o json | grep cloudand_db_url | grep -v last | awk '{print $2}' | tr -d ',' | tr -d '"' | base64 -d
```

* Create a directory to save 

* Backup the Cloudant DB with the following commands:

```
  couchbackup --url "http://admin:orange@$IP:$PORT" --log backup.log --db "platform-db" > platform-db-backup.txt
```

where IP is the IP address of the master node, and PORT, the port number defined above.

You will see the following message:

```
root@icp-master:~/backup# couchbackup --url "http://admin:orange@$IP:$PORT" --log backup.log --db "platform-db" > platform-db-backup.txt
================================================================================
Performing backup on http://****:****@localhost:30069/platform-db using configuration:
{
  "bufferSize": 500,
  "log": "backup.log",
  "mode": "full",
  "parallelism": 5
}
================================================================================
  couchbackup:backup Fetching all database changes... +0ms
  couchbackup:backup Total batches received: 1 +137ms
  couchbackup:backup Written batch ID: 0 Total document revisions written: 39 Time: 0.265 +133ms
  couchbackup:backup Finished - Total document revisions written: 39 +3ms

```

and the following command:

```
  couchbackup --url "http://admin:orange@$IP:$PORT" --log backup.log --db "security-data" > security-data-backup.txt
```

and you will see the following message:

```
root@icp-master:~/backup#   couchbackup --url "http://admin:orange@$IP:$PORT" --log backup.log --db "security-data" > security-data-backup.txt
================================================================================
Performing backup on http://****:****@localhost:30069/security-data using configuration:
{
  "bufferSize": 500,
  "log": "backup.log",
  "mode": "full",
  "parallelism": 5
}
================================================================================
  couchbackup:backup Fetching all database changes... +0ms
  couchbackup:backup Finished - Total document revisions written: 0 +185ms

```

Keep the backup file in a safe place, you will need it to store in a DR or new site.

## Simulate a loss of the ICP Cloudant database

Now let's simulate a loss of the Docker Registry. To do so, just delete the files under `/opt/ibm/cfc/cloudant` from every master nodes:
 
```
  rm -rf /opt/ibm/cfc/cloudant
```

It's recommended to use some automated script such as ansible scripts to delete all directories at the same time.
Here is an [sample ansible script to delete the folders](../scripts/move_cloundant_on_masters.yml)


## Restore your ICP Cloudant database

To restore the Cloudant DB, follow the below steps:

* Configure system to install Node 8:

```
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
```

* Install Node 8, if it is not installed

Run the following command to install node:

```
apt install nodejs
```

* Install npm, if it is not installed

Run the following command to install npm:

```
apt install -y npm
```

* Install couchrestore utility:

```
npm install -g @cloudant/couchbackup
```

* Clone this github project:

```
git clone https://github.com/ibm-cloud-architecture/icp-backup.git
cd icp-backup
```

* Expose the target ICP Cloudant DB as NodePort service, as documented above (or deploy the restore utility as kubernetes Job):

```
cd scripts
kubectl --namespace=kube-system apply -f CloudantDBNodePort.yaml
kubectl --namespace=kube-system get svc cloudantdb-ext -o json

export PORT=<Node port associated with Pod port 5984>

```

* Move the backup source file to the target Environment

* Restore the database, where IP is the IP address of the master node to be restored:
```
  couchrestore --url "http://admin:orange@$IP:$PORT" --db "platform-db" < platform-db-backup.txt
  couchrestore --url "http://admin:orange@$IP:$PORT" --db "security-data-db" < security-data-backup.txt
```

Where the port 31890 is the NodePort maps to the Cloudant endpoint of 5984.
