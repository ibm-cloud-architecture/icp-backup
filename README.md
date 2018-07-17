# Backup and Restore (BUR) of IBM Cloud Private

## Introduction

In this document, we will describe how to back up and restore your IBM Cloud Private (ICP) environment.  Understanding some of the components and processes have changed, we have begun to denote versions in the effected steps.  Currently we are providing backup process, procedures and suggestions for all nodes except Vulnerability Advisor (check back will be adding soon)..


### General Guidance on ICP Backup

Consider the backup and recovery procedures to best meet your resilience requirements.  Each implementation will have its own specific requirements and thus potentially its own procedures and best-practices.  Possible recovery / failure scenarios should be rehearsed in your non-production environment to verify their validity.  Each backup and recovery (BUR) solution will rely upon the enterprise for specific procedures and tooling to manage backups of the cluster nodes, their filesystems and persistent storage solution(s).

When developing your plan, along side the standard infrastructure failure scenarios, consider the following possible node failures:  Boot, Worker, Proxy, Management, Master in single Master topology, Master in multi-Master topology.  Consider failure of your shared storage / persistent storage solution.  Also, consider the possiblity of catastrophic failures such as multiple Masters and the entire cluster potentially including a DR declaration.

Currently, since we do not require any data from **Worker Nodes** and **Proxy Nodes**, and we can simply recreate them from the command line, we **will not create backups of these nodes.**
### Notes About etcd

ICP and Kubernetes rely heavily on etcd to store the Kubernetes and Calico configurations.  According to the etcd documentation: (https://coreos.com/etcd/docs/latest/v2/admin_guide.html#disaster-recovery)

> A user should avoid restarting an etcd member with a data directory from an out-of-date backup. Using an out-of-date data directory can lead to inconsistency as the member had agreed to store information via raft then re-joins saying it needs that information again. For maximum safety, if an etcd member suffers any sort of data corruption or loss, it must be removed from the cluster. Once removed the member can be re-added with an empty data directory.

### Notes About ICP Components

In ICP there are several components that help maintain the state of Kubernetes and ICP components.  We have taken care to make special note of each of these component stores:

* etcd
* Docker Registry
* Audit Logs
* Cloudant (ICP 2.1.0.2 and before)
* MongoDB (ICP 2.1.0.3 and after)
* MariaDB
* certificates

Based upon these components we recommend the following flow:

![flow](images/icp-backup-flow.png)

> It is important to note that you will leverage the same best-practices you use elsewhere in your datacenter.  The special procedures for backup of ICP compents are in addition to (and rely upon) these already proven techniques that must be in place.

## Backup and Recovery:  Breaking it Down

This guide segments the backup process into two logical super-steps:

* Initial Backup:  Backup of the entire cleanly installed environment post deplployment of the initial solution topology.  This will be used as a basis for certain recovery scenarios.

* Steady State:  Specialized backup of individual ICP components.

## Cluster Procedures

[Backup and restore the entire environment](docs/entire.md)

[Backup and restore ICP components](docs/components.md)


## Managing Persistent Volumes

[Back up and restore the Persistent Volumes](docs/pvs.md)


## Backlog and Notes

[Procedures on our backlog, participation is invited](docs/some.md)


## Additional information

* [How to restore a master node deployed to AWS](https://github.ibm.com/jkwong/icp-aws-hertz/blob/master/MasterNodeRecovery.md)

* [Everything you ever wanted to know about using etcd with Kubernetes v1.6 (but were afraid to ask)](https://www.mirantis.com/blog/everything-you-ever-wanted-to-know-about-using-etcd-with-kubernetes-v1-6-but-were-afraid-to-ask/)

* [OpenShift Backup and Restore](https://docs.openshift.com/container-platform/3.5/admin_guide/backup_restore.html#etcd-backup)

* [Kubernetes Backups](https://kubernetes.io/docs/getting-started-guides/ubuntu/backups/)

* [Using utilities to recover Tectonic clusters](https://coreos.com/tectonic/docs/latest/troubleshooting/bootkube_recovery_tool.html)
