echo Deleting job
kubectl delete job icp-cloudant-backup

echo Creating job
kubectl create -f ../jobs/icp-cloudant-backup-job.yaml