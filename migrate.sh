#!/usr/bin/env bash

latest=9
./flyway.sh ${1:-migrate} src/config/${2:-local}/usa.properties $latest
./flyway.sh ${1:-migrate} src/config/${2:-local}/gbr.properties $latest
./flyway.sh ${1:-migrate} src/config/${2:-local}/aus.properties $latest