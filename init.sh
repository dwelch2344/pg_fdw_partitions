#!/usr/bin/env bash

set -e

docker-compose down
docker-compose up -d

sleep 1.5

./flyway.sh $1 src/config/${2:-local}/usa.properties 1.1
./flyway.sh $1 src/config/${2:-local}/gbr.properties 1.1
./flyway.sh $1 src/config/${2:-local}/aus.properties 1.1

./migrate.sh $1