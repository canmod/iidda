#!/bin/sh
docker container kill $(docker ps -q)

docker build $1 -t schoolterms .
docker rmi $(docker images -qa -f 'dangling=true')
docker rm school
docker run -d \
    --name school \
    --mount type=bind,source="$(PWD)"/derived-data,target=/home/docker/derived-data \
    --rm \
    schoolterms
