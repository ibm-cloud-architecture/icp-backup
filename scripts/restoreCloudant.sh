JOB=icp-cloudant-restore
CONFIGMAP=cloudant-dbs

DBS=$1

echo Deleting job
kubectl delete job $JOB

echo Deleting config map
kubectl delete configmap $CONFIGMAP

echo Creating config map
export DBNAME=$DBS
kubectl create configmap $CONFIGMAP --from-literal=dbnames=$DBS 

echo Creating job
kubectl create -f ../resources/icp-cloudant-restore-job.yaml

kubectl describe job $JOB