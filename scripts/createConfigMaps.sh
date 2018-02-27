COUNTER=0
RANGE=100
SNAKE_SIZE=20

while true 
do

	let DELETE=($RANGE+$COUNTER-$SNAKE_SIZE)%100
	echo "Deleting key snake-$DELETE"
	kubectl delete configmap snake-$DELETE

	CONFIG_MAP=snake-$COUNTER
	KEY=k-$COUNTER
	VALUE=$(date)
	echo "Adding key: $KEY, value: $VALUE"
	kubectl create configmap $CONFIG_MAP --from-literal=$KEY=$VALUE

	let COUNTER=(COUNTER+1)%RANGE

	count=$(kubectl get cm | grep snake- | wc -l)

	echo "Number of config maps: $count"

	sleep 1
done