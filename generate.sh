#!/usr/bin/env bash


for i in `seq 1 50`;
do
    for j in `seq 1 10`;
    do
        PGPASSWORD=trebo-au psql -h localhost -p 5503 -U obert-au -d postgres -c 'select shared.hack_it(10000)' >> /tmp/generate.log 2>&1
    done
    echo "ITERATION $i"
done
