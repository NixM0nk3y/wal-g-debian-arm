#!/bin/bash -ex

DIRNAME=$(dirname "$0")

containerID=$(docker run --detach nixm0nk3y/timescaledb-debian-arm:latest /bin/sleep 120)
docker exec $containerID bash -c "mkdir /tmp/packages; mv ./src/timescaledb/build/*.deb /tmp/packages"
docker cp "$containerID:/tmp/packages" .
sleep 1
docker kill "$containerID"
docker rm "$containerID"
