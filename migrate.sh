#!/usr/bin/env bash

latest=9

echo -e "\n\n"
#read -p "Press enter for USA"
echo -e "\n\n"
./flyway.sh ${1:-migrate} src/config/${2:-local}/usa.properties $latest "${@:3}"

echo -e "\n\n"
#read -p "Press enter for GBR"
echo -e "\n\n"
./flyway.sh ${1:-migrate} src/config/${2:-local}/gbr.properties $latest "${@:3}"

echo -e "\n\n"
#read -p "Press enter for AUS"
echo -e "\n\n"
./flyway.sh ${1:-migrate} src/config/${2:-local}/aus.properties $latest "${@:3}"