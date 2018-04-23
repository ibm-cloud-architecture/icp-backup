JOB=icp-cloudant-restore
DBS=$1

echo Deleting job
kubectl delete job $JOB

echo Creating job
echo Databases: $DBS
DBNAME=$DBS
kubectl create -f ../resources/icp-cloudant-restore-job.yaml

kubectl describe job $JOB