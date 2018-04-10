COMPONENT=$1
VERSION=$2

echo Building component $COMPONENT at version $VERSION
cd ../src/$COMPONENT

IMAGE=patrocinio/icp-backup-$COMPONENT:$VERSION
docker build -f Dockerfile-$VERSION --build-arg version=$VERSION -t $IMAGE .
