#!/bin/bash
IMAGEID=$(docker images | awk -v repo="$REPOSITORY" -v tag="local" 'index($1, repo) && index($2, tag) {print $3}')

echo "$filename"
echo "$ORGANIZATION"
echo "$REPOSITORY_NAME"
echo "$VERSION"
echo "${IMAGEID}"
#
docker tag "${IMAGEID}" ${ORGANIZATION}/${REPOSITORY_NAME}:${VERSION}
docker tag "${IMAGEID}" ${ORGANIZATION}/${REPOSITORY_NAME}:latest

docker push ${ORGANIZATION}/${REPOSITORY_NAME}:${VERSION}
docker push ${ORGANIZATION}/${REPOSITORY_NAME}:latest
#cleanup
docker rmi -f ${IMAGEID}