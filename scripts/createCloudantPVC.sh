echo Creating Cloudant PVC...

kubectl delete pvc cloudant-backup

kubectl create -f ../resources/cloudant_backup_pvc.yaml
