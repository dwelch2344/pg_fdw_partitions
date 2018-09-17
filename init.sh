#!/usr/bin/env bash

set -e


#if test $# -lt 2
#then
#    docker-compose down
#    docker-compose up -d
#else
#    echo "Not messing with docker since environment was specified"
#fi

sleep 1.5


echo -e "\n\n"
#read -p "Press enter for 1.1 in USA"
echo -e "\n\n"
./flyway.sh $1 src/config/${2:-local}/usa.properties 1.1 -repeatableSqlMigrationPrefix=DONT_USE_ME

echo -e "\n\n"
#read -p "Press enter for 1.1 in GBR"
echo -e "\n\n"
./flyway.sh $1 src/config/${2:-local}/gbr.properties 1.1 -repeatableSqlMigrationPrefix=DONT_USE_ME

echo -e "\n\n"
#read -p "Press enter for 1.1 in AUS"
echo -e "\n\n"
./flyway.sh $1 src/config/${2:-local}/aus.properties 1.1 -repeatableSqlMigrationPrefix=DONT_USE_ME

./migrate.sh $1 $2