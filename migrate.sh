#!/usr/bin/env bash

latest=9
./flyway.sh migrate src/config/usa.properties $latest
./flyway.sh migrate src/config/gbr.properties $latest
./flyway.sh migrate src/config/aus.properties $latest