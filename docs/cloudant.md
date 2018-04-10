# Back up and restore the Cloudant database in IBM Cloud Private

IBM Cloudant local is used by IBM Cloud Private(ICP) to store information for OIDC service, metering service (IBM® Cloud Product Insights), Helm repository server, and Helm API server.
It runs as a kubernetes Statefulset and mount to local host path. The StatefulSet is exposed as HeadLess service as “cloudantdb”.
There are 8 databases in ICP:

* _users
* helm_repos
* metrics
* metrics_app
* platform-db
* security-data
* stats
* tgz_files_icp

In this page, we'll describe how to back up and restore the Cloudant local db in IBM Cloud Private.

## Flow

Here is the sequence of steps we will run to back up and validate the Cloudant databases.

* Add data to the Cloudant database
* Define a Persistent Volume
* Create a Persistent Volume Claim
* Back up Cloudant database
* Simulate a loss (by deleting the data we added above)
* Restore the Cloudant database
* Validate the data is back

## Add data to the Cloudant database

Cloudant holds different kinds of data for ICP, such as Helm repositories and metrics.

Run the following procedure to add a new Helm repository to ICP:

* Log on to the ICP UI
* Click *Manage &rarr; Helm Repositories*
* Click *Add Repository*
* Copy one of the existing Repositories URL to your buffer
* Add a new repository
  - name *test_cloudant*
  - URL: the value copied in the buffer 
*  Click Add

You will see the new repository in the list

## Define a Persistent Volume

We will store the Cloudant backup as a Kubernetes Persistent Volume Claim (PVC), so that you can use the same procedure defined to back up the PVCs

So we need first to create a Persistent Volume (or a Storage Class Provider), if there is none.
Follow the guidelines for your environment to create a Persistent Volume

## Create a Persistent Volume Claim

Run the following procedure the back up Cloudant to the PVC (assuming you are in the directory `icp-backup/scripts`

```
./switchNamespace.sh kube-system
./createCloudantPVC.sh
```

You will see the following output:

```
patro:scripts edu$ ./createCloudantPVC.sh
Creating Cloudant PVC...
Error from server (NotFound): persistentvolumeclaims "cloudant-backup" not found
persistentvolumeclaim "cloudant-backup" created
```

## Back up Cloudant database

Now we can back up the Cloudant database.

Run the following procedure:

```
./backupCloudant.sh
```

And you will see the following output:

```
patro:scripts edu$ ./backupCloudant.sh
Deleting job
Error from server (NotFound): jobs.batch "icp-cloudant-backup" not found
Creating job
job "icp-cloudant-backup" created
Name:		icp-cloudant-backup
Namespace:	default
Image(s):	patrocinio/icp-backup-cloudant-backup:latest
Selector:	controller-uid=31cc1adb-3439-11e8-aa21-067c83088870
Parallelism:	1
Completions:	1
Start Time:	Fri, 30 Mar 2018 18:41:28 +0200
Labels:		controller-uid=31cc1adb-3439-11e8-aa21-067c83088870
		job-name=icp-cloudant-backup
Pods Statuses:	1 Running / 0 Succeeded / 0 Failed
Volumes:
  cloudant-backup:
    Type:	PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:	cloudant-backup
    ReadOnly:	false
Events:
  FirstSeen	LastSeen	Count	From			SubObjectPath	Type		Reason			Message
  ---------	--------	-----	----			-------------	--------	------			-------
  1s		1s		1	{job-controller }			Normal		SuccessfulCreate	Created pod: icp-cloudant-backup-g7hjx
```

You can see the output of the Pod by running the following command:

```
kubectl logs -f <cloudant-backup-id>
```

where <cloudant-backup-id> is the Pod ID, as shown in the last time of the previous output. This Job takes a few minutes; at the end, you should see a message like this:

```
2018-03-30T19:04:02.785Z couchbackup:backup Finished - Total document revisions written: 1
```

## Simulate a loss 

Now we are going to simulate a loss in the Cloudant database. 

As we added the Helm repository *test_cloudant*, let's remove it, by following these steps in the ICP UI:

* Click *Manage &rarr; Helm Repositories*
* In the line containing, *test_cloudant*, select the Action menu, and click *Delete*
* In the confirmation dialog, click *Delete* again 

You will see that the *test_cloudant* database disappears from the list.

## Restore the Cloudant database

Let's now recover the Cloudant database from the backup.

Run the following script to restore the Cloudant database:

```
./restoreCloudant.sh
```

You will see the following output:

```
kubectl describe job $JOBpatro:scripts edu$ ./restoreCloudant.sh
Deleting job
Error from server (NotFound): jobs.batch "icp-cloudant-restore" not found
Creating job
job "icp-cloudant-restore" created
Name:		icp-cloudant-restore
Namespace:	kube-system
Image(s):	patrocinio/icp-backup-cloudant-backup:latest
Selector:	controller-uid=65f3c397-344e-11e8-aa21-067c83088870
Parallelism:	1
Completions:	1
Start Time:	Fri, 30 Mar 2018 21:13:15 +0200
Labels:		controller-uid=65f3c397-344e-11e8-aa21-067c83088870
		job-name=icp-cloudant-restore
Pods Statuses:	1 Running / 0 Succeeded / 1 Failed
Volumes:
  cloudant-backup:
    Type:	PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:	cloudant-backup
    ReadOnly:	false
Events:
  FirstSeen	LastSeen	Count	From			SubObjectPath	Type		Reason			Message
  ---------	--------	-----	----			-------------	--------	------			-------
  7s		7s		1	{job-controller }			Normal		SuccessfulCreate	Created pod: icp-cloudant-restore-8bwq8
  4s		4s		1	{job-controller }			Normal		SuccessfulCreate	Created pod: icp-cloudant-restore-lpb4c
```

Now, look at the Kubernetes Pod by running the following command:

```
kubectl logs -f <pod-id>
```

where `<pod-id>` is the ID displayed in the last line of the previous output.

## Validate the data is back