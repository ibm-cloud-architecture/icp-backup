# Backup and restore the entire ICP environment

As described in the introduction, we don't recommend using a traditional server backup to persist an ICP environment (because of etcd).

However, a full environment backup might be required to quickly restore the environment to its initial state, then apply specific component restore, as documented at [Backup and restore ICP components](components.md)

We are assuming here that an ICP environment has already been deployed.

## Back up your ICP environment

 Here are the steps you should follow to back up your ICP environment
 
### Stop the ICP servers (Virtual Machines)

### Take a backup of your environment

We recommend taking the back up right after installing ICP. 

The tool to use for the backup depends on the environment ICP has been deployed:

* For a VMware environment, you can use VMware snapshot, Veaam, or IBM Spectrum Protect

* For a public cloud environment, use the proper backup solution

* For any environment, you can always use the storage-provided mechanism for backup

## Validate your backup

No backup is good until we test it can restore the environment successfully.

Follow these steps to validate your backup

### Destroy the Virtual Machines

Follow the procedures in your environment to destroy the VMs

### Restore the Virtual Machines from the backups

Again, follow the specific procedure for your environment to restore the VMs

## Restore the Virtual Machines

## Validate the ICP components

## Validate the sample application