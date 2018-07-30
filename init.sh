#!/usr/bin/env bash

set -e

docker-compose up -d

sleep 1.5


echo -e "\n\n"
#read -p "Press enter for 1.1 in USA"
echo -e "\n\n"
./flyway.sh $1 src/config/${2:-local}/usa.properties 1.1

echo -e "\n\n"
#read -p "Press enter for 1.1 in GBR"
echo -e "\n\n"
./flyway.sh $1 src/config/${2:-local}/gbr.properties 1.1

echo -e "\n\n"
#read -p "Press enter for 1.1 in AUS"
echo -e "\n\n"
./flyway.sh $1 src/config/${2:-local}/aus.properties 1.1

./migrate.sh $1 $2