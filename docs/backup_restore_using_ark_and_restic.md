# Backup and Restore of Applications running on ICP

In this document, we will describe how to back up and restore your applications running on IBM Cloud Private (ICP) environment using Ark and Restic.


### Introduction to Veloro (previously known as Ark) and Restic

[Veloro](https://github.com/heptio/velero); previously known as Ark is an open source, kubernetes backup recovery utility from Heptio. As of writing this article, the Heptio team and the community contributors are aggressively working on the first Velero release and migrating current Ark deployments to Velero. For the purpose of this article we will refer to the backup utility as Ark.

Ark provides backup and restore capabilities for all or part of your kubernetes cluster. It backs up all tags, deployments, persistent volumes, and more. Since v0.6.0, Ark has adopted a plugin model which enables anyone to easily implement additional object and block storage backends, outside of the main Ark repository.

With the [integration of Restic](https://blog.heptio.com/ark-v0-9-alpha-now-with-restic-14ad6b402ab3), Ark now natively supports backing up and restoring data from any Kubernetes volume or persistent volume. Restic takes file-level backups of your data, and has several key features that make it a great fit for Ark’s needs:

Supports multiple storage backends, including IBM Cloud Object Storage, Amazon S3, Google Cloud Storage, Azure Blob Storage, and Minio
* Fully encrypts backup data at rest and in transit with AES-256 in counter mode
* Only backs up data that has changed since the prior backup, using content-defined chunking
* De-duplicates data within a single backup for efficient use of storage

As Public Cloud Providers continue to drive down costs of Object Storage services; using Ark and Restics with Object storage as a backup target makes a promising option to consider. We will explore this very scenario for Application backup and restore operations below.

### Scope

In this guide, we will set up and configure the Ark client on a local machine, and deploy the Ark server into our Kubernetes cluster. We'll then deploy a sample Nginx app that uses a Persistent Volume for logging, backup the application to IBM Cloud Object Storage, simulate a disaster recovery scenario and restore the application with its persistent volume.

We are following the [companion guide for IBM Cloud Kubernetes Service (IKS)](https://medium.com/@mlrborowski/using-ark-and-restic-to-provide-dr-for-ibm-kubernetes-service-cae53cfe532) with the following differences:
1. Using ICP vs. IKS
2. Using NFS storage as the storage options for the ICP cluster vs. GlusterFS

This proves:
1. The underlying framework including kubernetes is exactly the same in ICP and IKS as the open sourced kubernetes project; supporting portability across public, private and multi-cloud environments.
2. Ark and Restic is storage agnostic.

In order to follow all of the recommendations in this guide, it is assumed that you have already provisioned an ICP cluster and set up NFS storage for the same, and are able to have access to your cluster immediately post-install.

A simple overview of the process is as follows:

* Login (or first create) to your IBM Cloud Account.
* Create and configure IBM object storage service.
* Install Ark Client.
* Configure Ark and Restic.
* Login to your ICP cluster
* Install Ark and Restic into your ICP cluster.
* Deploy an application and make a change to the PV content.
* Run Ark backup.
* Delete the application and PV, simulating disaster.
* Restore application from Ark/Restic Backup and all is well again.

## Task 1: Setup your Backup target

We will use the IBM Cloud Object Storage (COS) service as the backup target.

### Step 1. Login to the IBM Cloud (or create you free account if this is your first time)

https://console.cloud.ibm.com

### Step 2. Create an IBM Cloud Object Storage Service Instance

To store Kubernetes backups, you need a destination bucket in an instance of Cloud Object Storage (COS) and you have to configure service credentials to access this instance.

If you don’t have a COS instance, you can create a new one, according to the detailed instructions in Creating a new resource instance. The next step is to create a bucket for your backups. Ark and Restic will use the same bucket to store K8S configuration data as well as Volume backups. See instructions in Create a bucket to store your data. We are naming the bucket arkbucket and will use this name later to configure Ark backup location. You will need to choose another name for your bucket as IBM COS bucket names are globally unique. Choose “Cross Region” Resiliency so it is easy to restore anywhere.

[COS Bucket Creation (arkbucket shown but create restic bucket also)](./images/ark/icos_create_bucket.png)


The last step in the COS configuration is to define a service that can store data in the bucket. The process of creating service credentials is described in Service credentials. Several comments:

```
Your Ark service will write its backup into the bucket, so it requires the “Writer” access role.
Ark uses an AWS S3 compatible API. Which means it authenticates using a signature created from a pair of access and secret keys — a set of HMAC credentials. You can create these HMAC credentials by specifying {“HMAC”:true} as an optional inline parameter. See step 3 in the Service credentials guide.
```

[COS Service Credentials](./images/ark/icos_service_credentials.png)

After successfully creating a Service credential, you can view the JSON definition of the credential. Under the ```cos_hmac_keys``` entry there are ```access_key_id``` and ```secret_access_key```. We will use them later.



## Task 2: Setup Ark

### Step 3. Download and Install Ark

Download Ark as described here: https://heptio.github.io/ark/v0.10.0/. A single tar ball download (https://github.com/heptio/ark/releases) should install the Ark client program along with the required configuration files for your cluster.

Note that you will need Ark v0.10.0 or above for the Restic integration as shown in these instructions.
Add the Ark client program (ark) somewhere in your $PATH.

### Step 4. Configure Ark Setup

Configure your kubectl client to access your IKS deployment. From the Ark root directory, edit the file config/ibm/05-ark-backupstoragelocation.yaml file. Add your COS keys as a Kubernetes Secret named cloud-credentials as shown below. Be sure to update <access_key_id> and <secret_access_key> with the value from your IBM COS service credentials. The remaining changes in the file are in the section showing the BackupStorageLocation resource named default. Configure access to the bucket arkbucket (or whatever you called yours) by editing the spec.objectstore.bucket section of the file. Edit the COS region and s3URL to match your choices.

```
apiVersion: v1
kind: Secret
metadata:
  namespace: heptio-ark
  name: cloud-credentials
stringData:
  cloud: |
    [default]
    # UPDATE ME: the value of “access_key_id” of your COS service credential
    aws_access_key_id = <access_key_id>
    # UPDATE ME: the value of “secret_access_key” of your COS service credential
    aws_secret_access_key = <secret_access_key>
---
apiVersion: ark.heptio.com/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: heptio-ark
spec:
  provider: aws
  objectStorage:
    bucket: arkbucket
  config:
    s3ForcePathStyle: "true"
    s3Url:  http://s3-api.us-geo.objectstorage.softlayer.net
    region: us-geo
```
The file should look something like this when done.

### Step 5. Login to your ICP cluster

[ICP Client Credentials](./images/ark/icp_client_config.png)

After you login to the cluster's Admin Console, copy the client configurations from your profile. You will use these credentials to login to your cluster from a terminal.

### Step 6. Deploy Ark into your IBM ICP Instance

Run the following commands from the Ark root directory:
```kubectl apply -f config/common/00-prereqs.yaml```

```kubectl apply -f config/ibm/05-ark-backupstoragelocation.yaml```

```kubectl apply -f config/ibm/10-deployment.yaml```

```kubectl apply -f config/aws/20-restic-daemonset.yaml```

Verify that Ark and Restic are running correctly on your ICP cluster with the following command:

```kubectl -n heptio-ark get pods```

which should show pods running similar to this:

```
NAME READY STATUS RESTARTS AGE
ark-5464586757-q2crr 1/1 Running 0 5m
restic-7657v 1/1 Running 0 5m
restic-hh677 1/1 Running 0 5m
restic-mb9vh 1/1 Running 0 5m
```

Note above that the count may vary as there is one Ark pod and a Restic Daemon set (in this case 3 pods, one per worker node).


## Step 7. Create Namespace, Persistent Volume and Persistent Volume Claim

You can use the ICP admin console to create the Namespace, Persistent Volume and Persistent Volume Claim as below.


[ICP create Namespace](./images/ark/icp_create_namespace.png)

Under the Platform, Storage settings create the Persistent Volume and Persistent Volume Claim.

[ICP create Persistent Volume](./images/ark/icp_create_pv.png)
[ICP create Persistent Volume Claim](./images/ark/icp_create_pvc.png)



## Step 8. Deploy a sample Application with a Volume to be Backed Up

From the Ark root directory cut the yaml code below and save it asconfig/ibm/with-pv.yaml. We are creating a simple nginx deployment in its own namespace along with a service and a dynamically provisioned PV where we store nginx logs. Note the annotation: backup.ark.heptio.com/backup-volumes: nginx-logs below which tells Restic the volume name that we are interested in backing up.

```
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
 name: nginx-deployment
 namespace: nginx-example
spec:
 replicas: 1
 template:
   metadata:
     annotations:
       backup.ark.heptio.com/backup-volumes: nginx-logs
     labels:
       app: nginx
   spec:
     volumes:
       - name: nginx-logs
         persistentVolumeClaim:
           claimName: claim-nginx-logs
     containers:
     - image: nginx:1.7.9
       name: nginx
       ports:
       - containerPort: 80
       volumeMounts:
         - mountPath: "/storage"
           name: nginx-logs
           readOnly: false
---
apiVersion: v1
kind: Service
metadata:
 labels:
   app: nginx
 name: my-nginx
 namespace: nginx-example
spec:
 ports:
 - port: 80
   targetPort: 80
 selector:
   app: nginx
 type: LoadBalancer
```
Now we can deploy this sample app by running the following from the Ark root directory:

```kubectl create -f config/ibm/with-pv.yaml```

We can check if the storage has been provision with:

```kubectl -n nginx-example get pvc```

You may have to run this over the course of a few minutes as the PVC gets bound. It will show pending but eventually show as bound similar to:

```
NAME STATUS VOLUME CAPACITY ACCESS MODES STORAGECLASS AGE
claim-nginx-logs Bound pvc-cab7c88b-e908–11e8–8afb-c295f183323f 24Gi RWX ibmc-file-bronze 3m
```

Now that we have a volume mounted we can find out the nginx pod name and put something in the volume (or just access the nginx web frontend and see access logs grow). Get your pod name with the following command (sample output shown):
```
kubectl -n nginx-example get pods


NAME                                READY     STATUS    RESTARTS   AGE
nginx-deployment-54c66df98b-6ppt5   1/1       Running   0          25s
```
Using the above pod name (yours will differ) we can log into the instance and add a file with the following commands:

```
 kubectl -n nginx-example exec -it nginx-deployment-54c66df98b-6ppt5 -- /bin/bash
root@nginx-deployment-54c66df98b-6ppt5:/# cd /storage
root@nginx-deployment-54c66df98b-6ppt5:/storage# echo "hw test it is late" > hw-test.txt
```

We now have some content we would expect to be saved and restored with the addition of our hw.txt file. You can, of course just access the nginx front end service via your browser and see the access.log grow also.

## Step 8. Use Ark and Restic to backup K8S config and volume.

We can backup up our sample application by scoping the backup to the application’s namespace as follows:

```
ark backup create my-nginx-bu-test-late --include-namespaces nginx-example

Backup request “my-nginx-bu-test-late” submitted successfully.
Run `ark backup describe my-nginx-bu-test-late` for more details.
```

We can check the result with:

```ark backup describe my-nginx-bu-test-late --details```

which after repeating a few times the result should show a complete status.

[Ark completion](./images/ark/ark_completion.png)

If you examine your IBM Cloud COS bucket associated with the backup you will see that a set of files has appeared.

## Step 9. Simulating Disaster

With the following commands we will delete our application configuration and the PV associated and confirm they are removed:

```
kubectl delete namespace nginx-example
namespace “nginx-example” deleted
```
```
kubectl get pvc -n nginx-example
No resources found.
```
```
kubectl get pods -n nginx-example
No resources found.
```
## Step 10. Recovering from Disaster

We can restore the application and volume with the following command:

```
ark restore create --from-backup my-nginx-bu-test-late

Restore request "my-nginx-bu-test-late-20190207183813" submitted successfully.
Run `ark restore describe my-nginx-bu-test-late-20190207183813` or `ark restore logs my-nginx-bu-test-late-20190207183813` for more details.
```

Restoring will take longer because we are dynamically provisioning another network drive behind the scenes.  Run the ark restore describe <restore_request_name> --details command to observe the progress.

```
ark restore describe my-nginx-bu-test-late-20190207183813 --details
Name:         my-nginx-bu-test-late-20190207183813
Namespace:    heptio-ark
Labels:       <none>
Annotations:  <none>

Backup:  my-nginx-bu-test-late

Namespaces:
  Included:  *
  Excluded:  <none>

Resources:
  Included:        *
  Excluded:        nodes, events, events.events.k8s.io, backups.ark.heptio.com, restores.ark.heptio.com
  Cluster-scoped:  auto

Namespace mappings:  <none>

Label selector:  <none>

Restore PVs:  auto

Phase:  Completed

Validation errors:  <none>

Warnings:  <none>
Errors:    <none>

Restic Restores:
  Completed:
    nginx-example/nginx-deployment-54c66df98b-6ppt5: nginx-logs

```

Within a minute or two we see our application is up and the volume recovered using the commands below (your pod name will differ). We dump our “hello world” file (hw.txt) and its contents are what we had per-disaster, mission accomplished!

```
kubectl get pods -n nginx-example

NAME READY STATUS RESTARTS AGE
nginx-deployment-68fbbf4d7c-mkfnt 1/1 Running 0 6m

kubectl -n nginx-example exec -it nginx-deployment-68fbbf4d7c-mkfnt -- cat /var/log/nginx/hw.txt

hw
```
## Summary

Ark and Restic have made the lives of Kubernetes developers and administrators a lot easier when it comes to DR. Using ubiquitously available object storage as the backend, a Kubernetes API aware client and cluster runtime agents, Ark/Restic has solved the Kubernetes DR challenge in an elegant yet completely accessible way. Given its ease of use and reach feature set, Ark/Restic has expanded the set of achievable use cases to now include developer workflows and potentially even cloud to cloud migration. The sky is the limit with Ark cloud DR.
