MASTER_IP=$1

echo Configuring Helm CLI for ICP on $MASTER_IP
bx pr login -a https://$MASTER_IP:8443 --skip-ssl-validation
# bx pr cluster-config mycluster
