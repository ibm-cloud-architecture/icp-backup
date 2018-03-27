JOB=icp-cloudant-restore

echo Deleting job
kubectl delete job $JOB

echo Creating job
kubectl create -f ../resources/icp-cloudant-restore-job.yaml

kubectl describe job $JOB