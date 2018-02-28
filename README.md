# How to back up (and restore) an IBM Cloud Privatre environment

## Introduction

In this document, we will describe how to back up and restore your IBM Cloud Private (ICP) environment


## General guidance on ICP backup

ICP and Kubernetes realy heavily on etcd to store the configuration. According to the etcd documentation (https://coreos.com/etcd/docs/latest/v2/admin_guide.html#disaster-recovery)

> A user should avoid restarting an etcd member with a data directory from an out-of-date backup. Using an out-of-date data directory can lead to inconsistency as the member had agreed to store information via raft then re-joins saying it needs that information again. For maximum safety, if an etcd member suffers any sort of data corruption or loss, it must be removed from the cluster. Once removed the member can be re-added with an empty data directory.

So we recommend back up specific ICP components:

* etcd
* Docker Registry
* cloudant
* anything else?

Based on that, we will describe two solutions: 

* Back up the entire environment, after the initial solution, so that it can be recreated quickly

* Back up individual ICP components

## Solutions

[Backup and restore the entire environment](entire.md)

[Backup and restore ICP components](components.md)


## TBD

[Back up and restore the Persistent Volumes](pvs.md)


## Back-burner

[Backup and restore some ICP node](some.md)


## Additional information

* [How to restore a master node deployed to AWS](https://github.ibm.com/jkwong/icp-aws-hertz/blob/master/MasterNodeRecovery.md)

* [Everything you ever wanted to know about using etcd with Kubernetes v1.6 (but were afraid to ask)](https://www.mirantis.com/blog/everything-you-ever-wanted-to-know-about-using-etcd-with-kubernetes-v1-6-but-were-afraid-to-ask/)

* [OpenShift Backup and Restor](https://docs.openshift.com/container-platform/3.5/admin_guide/backup_restore.html#etcd-backup)

* [Kubernetes Backups](https://kubernetes.io/docs/getting-started-guides/ubuntu/backups/)

* [Using utilities to recover Tectonic clusters](https://coreos.com/tectonic/docs/latest/troubleshooting/bootkube_recovery_tool.html)

