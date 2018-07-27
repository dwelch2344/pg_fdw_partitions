#!/usr/bin/env bash

LOCATIONS=$(dirname "$0")/src/main/resources/db/migration/default
cd "$LOCATIONS"
LOCATIONS=$(pwd)
cd -
flyway $1 -configFile=$2 -locations="filesystem:$LOCATIONS" -target=$3 -X