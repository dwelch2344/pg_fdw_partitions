#!/usr/bin/env bash

set -e

docker-compose down
docker-compose up -d

sleep 1.5

./flyway.sh $1 src/config/usa.properties 1.1
./flyway.sh $1 src/config/gbr.properties 1.1
./flyway.sh $1 src/config/aus.properties 1.1

./migrate.sh $1