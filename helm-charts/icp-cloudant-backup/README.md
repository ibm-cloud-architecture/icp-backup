# ICP Cloudant Backup Helm Chart

The Cloudant backup helm chart deploys the ICP Cloudant backup utility to an ICP cluster.

Two cron jobs get deployed:
- icp-cloudant-backup
- icp-cloudant-backup-cleanup

# ICP Cloudant Backup

The ICP Cloudant backup cronjob, takes a backup of the ICP Cloudant databases.  Certain databases may be excluded from the backup based on the names provided with the `--exclude` parameter as specified using the `.Values.backup.args.exclude` value.

The backup schedule is set using `.Values.backup.cronjob.schedule` value.

# ICP Cloudant Backup Cleanup

The backup cleanup cronjob deletes any directories above the retention count.

The cleanup schedule is set using the `.Values.cleanup.cronjob.schedule`
