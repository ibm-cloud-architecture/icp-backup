FILE_SERVER=fsf-wdc0701b-fz.adn.networklayer.com
FILE_PATH=/IBM02SV625675_7/data01
TEMP_FILE=/tmp/volume.yaml

# args: 
# 1: file
# 2: begin
# 3: end
function create_pv () {
	for i in $(eval echo "{$2..$3}")
	do
   		echo Creating PV $i
   		kubectl delete pv d-${i}
		sed s/FILE_SERVER/$FILE_SERVER/g < volume_config/$1.yaml | \
   		sed s:FILE_PATH:$FILE_PATH:g  | \
   		sed s/FILE_SYSTEM/d-${i}/g > $TEMP_FILE

   		cat $TEMP_FILE
   		kubectl create -f /tmp/volume.yaml
	done
}

create_pv 'rwo' 1 20
create_pv 'rwx' 21 40
create_pv 'rwx-large' 41 50
create_pv 'rwo-large' 51 60

