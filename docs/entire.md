# Backup and Restore an Entire ICP Topology

As described in the introduction, we don't recommend using a traditional server backup alone to persist an ICP environment after the cluster is put into use (because of components suck as the etcd datastore).

However, a full environment backup might be required to quickly restore the environment (or a node / subset of nodes) to the initial state, with specific ICP component restores applied as documented at [Backup and Restore ICP Components](components.md)

In order to follow all of the recommendations in this guide, it is assumed that you are able to have access to your cluster immediately post-install.

## Back up your ICP environment

Here are the steps you should follow to take an initial backup your ICP environment.  Keep in mind our guiding principle:  **We do not take backups of nodes that we don't restore and just replace instead (Worker and Proxy).**

### Stop the ICP Servers (Virtual Machines)

For the process used in this guide you do not need to stop the entire cluster all at once, but it is important to note a few items.  When attempting to bring down an entire cluster always stop the Master nodes first otherwise they will begin rescheduling and attempting to recover.  This is not desired when you are attempting to acheive an organized steady state.  Once the Masters have been stopped you are free to proceed in any order you please.  For cluster restart proceed in reverse and pring the Masters up once all other nodes have resumed.

> Follow other best practices such as if you are downing worker nodes for some reason you will want to use the drain command prior to taking them offline.

Stop kubelet first, Kubelet may attempt to restart Docker processes otherwise.

```sudo systemctl stop kubelet```

Next stop Docker:   ```sudo systemctl stop docker```

Confirm that all processes are shutdown (be patient):  ```top```

and that all related network ports are no longer in use:  ```netstat –antp```

Once you have completed the other tasks for performing system maintenance or taking backups, to restart the cluster simply reboot the nodes (Masters Last).

> Yes, some of the time you can actually start the processes explicitly as stated below, but this is a good opportunity to reaffirm that these systems will start on their own.  Also, this team has seen much more consistent success via the shutdown -r now method.

If you wish to restart without a reboot, start Docker first and then follow with kubelet:

```sudo start docker ```

Pause for a moment then:

```sudo start kubelet```

You can follow the logs for kubelet:  ```sudo journalctl -e -u kubelet```

### Taking an Infrustructure Level Backup of Your Cluster

We recommend taking the backup immediately follwing the ICP installation.

> In the case that you are performing an upgrade, post upgrade, follow this procedure for taking a cold backup once again.  Retain both the post-upgrade and post-initial-install backups of the Master nodes.  As a special note, if you have an HA cluster you should be able to accomplish the backup of the Master nodes without having an outage.  Simply back them up one at a time.

The tool to use for the backup depends on your hosting environment and accepted tools..

* For a VMware environment, you can use VMware snapshot, Veaam, IBM Spectrum Protect, or any other approved snapshot tool that allows you to store this snapshot in perpetuity (forever).
* For a public cloud environment, use the backup solution preferred by the cloud provider.
* For any other environment, you can always use the storage-provided mechanism for backup, or other solution that allows you to accurately recreate the original state of the infrastructure and build.

### Validate your Backup

No backup is **good** until we test it by using it to successfully restore our cluster (or component thereof).

Follow these steps to validate your backup:

* Destroy the node (or nodes) via whichever means fits your potential / expected scenario
* Follow the provided steps to restore what was destroyed in the previous step
* Verify the validity of whatever was destroyed and restored

> The fact that an ICP node is running is a good thing, but that does not necessarily mean your restoration was successful.  In your non-production environments perform steps that force workload mobility.  Verify that you Masters are able to behave like Masters, Proxies like Proxies, .... you get the idea.
