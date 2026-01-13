#!/bin/bash

for container in $(container ls -q)
do
    bugs=$(container logs ${container} --boot | grep -E 'NULL|Oops|BUG')
    if [[ ! -z ${bugs} ]]
    then
        pid=$(ps aux | grep ${container} | grep -v grep | awk '{print $2}' | head -1)
        echo "killing bugged ${container}(${pid})"
        kill -9 ${pid}
    else
        container kill ${container}
    fi
done

