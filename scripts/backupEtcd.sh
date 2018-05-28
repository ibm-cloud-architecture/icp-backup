BASE_FILE_NAME=/data/etcd

. ./etcd.sh

CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")
echo "Current Time : $CURRENT_TIME"

FILE_NAME="$BASE_FILE_NAME.$CURRENT_TIME.db"
 echo "Back up to the following file: " "$FILE_NAME"

etcdctl3 snapshot save $FILE_NAME