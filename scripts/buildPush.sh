latest=$(ls ../src/$1 | sort -n | tail -1)
echo Version $latest
./buildComponent.sh $1 $latest
./pushComponent.sh $1 $latest
