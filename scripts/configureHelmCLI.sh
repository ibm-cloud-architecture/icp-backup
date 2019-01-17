MASTER_IP=$1

echo Configuring Helm CLI for ICP on $MASTER_IP
cloudctl login -a https://$MASTER_IP:8443 --skip-ssl-validation
