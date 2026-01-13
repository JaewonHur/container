#!/bin/bash

for cid in $(container ls -q)
do
    bugs=$(container logs ${cid} --boot | grep -E 'NULL|Oops|BUG')
    if [[ ! -z ${bugs} ]]
    then
        echo "======[${cid}]======"
        while IFS= read -r bug; do
            echo ${bug}
        done <<< "$bugs"
        echo -e "\n\n"
    fi
done
