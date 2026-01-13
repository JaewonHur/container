#!/bin/bash

mkdir -p logs/container logs/vessel

num_stress=${1:-1}
num_dockers=${2:-1}

name=$(date "+%H%M")
container_root="$HOME/Library/Application Support/com.apple.container/containers"
vessel_root="$HOME/Library/Application Support/Vessel/container"

if ! container system status; then
    "[-] container system start first!"
    exit
fi

if ! container image ls | grep linux-docker; then
    container build --tag linux-docker --file ./Dockerfile
fi

[ $VESSEL ] && {
    [ -d "${vessel_root}" ] || {
        echo "[-] Please install Vessel first"
        exit
    }

    [ -d "${vessel_root}"/stress ] || {
        echo "[-] Please pull 'ghcr.io/colinianking/stress-ng' through Vessel"
        exit
    }

    [ -d "${vessel_root}"/linux-docker ] || {
        echo "[-] Please build './Dockerfile' under tag 'linux-docker' through Vessel"
        exit
    }
}

echo "Containers naming with $name postfix" 

for i in $(seq 1 ${num_stress})
do
    container=stress-${name}-${i}
    echo "Creating stress-${name}-${i}"

    if [ -z $VESSEL ]; then
        container run --name ${container} --memory 4G --detach ghcr.io/colinianking/stress-ng --class filesystem --all 2
    else
        # container run --name ${container} --memory 4G -it --entrypoint /bin/bash ghcr.io/colinianking/stress-ng &
        container run --name ${container} --memory 4G --detach ghcr.io/colinianking/stress-ng --class filesystem --all 2
        # sleep 2
        container kill ${container}

        rm "${container_root}"/${container}/rootfs.ext4
        cp "${vessel_root}"/stress/fs "${container_root}"/${container}/rootfs.ext4

        container start ${container}
        container exec ${container} stress-ng --class filesystem --all 2 &> logs/vessel/${container}.log &
    fi
done

# for i in $(seq 1 ${num_dockers})
# do
#     container=fio-${name}-${i}
#     echo "Creating fio-${name}-${i}"
# 
#     container run -d --name ${container} fio
# done

if [ ! -z ${ONE_VM} ]; then
    container run -v docker1:/root/docker1 -v docker2:/root/docker2 --name linux-docker-${name} --memory 16G --detach linux-one-vm
    sleep 5

    # container exec linux-docker-${name} bash -c "DOCKER_HOST=unix:///root/docker1/docker.sock docker run --ulimit nproc=30000 -v /root/stress1:/stress1 ghcr.io/colinianking/stress-ng --class filesystem --all 2 --temp-path /stress1" &> logs/container/stress-${name}-1.log &
    # container exec linux-docker-${name} bash -c "DOCKER_HOST=unix:///root/docker2/docker.sock docker run --ulimit nproc=30000 -v /root/stress2:/stress2 ghcr.io/colinianking/stress-ng --class filesystem --all 2 --temp-path /stress2" &> logs/container/stress-${name}-2.log &

    container exec linux-docker-${name} /start1.sh &> logs/container/linux-docker-${name}-start1.log &
    container exec linux-docker-${name} /start2.sh &> logs/container/linux-docker-${name}-start2.log &
    exit 0
else

    for i in $(seq 1 ${num_dockers})
    do
        container=linux-docker-${name}-${i}
        echo "Creating ${container}"
    
        if [ -z $VESSEL ]; then
            container run --name ${container} --memory 8G --detach linux-docker
            sleep 1
            container exec ${container} /start.sh &> logs/container/${container}.log &
            sleep 1
        else
            container run --name ${container} --memory 8G --detach linux-docker
    
            container kill ${container}
    
            rm "${container_root}"/${container}/rootfs.ext4
            cp "${vessel_root}"/linux-docker/fs "${container_root}"/${container}/rootfs.ext4
    
            container start ${container}
            container exec ${container} /start.sh &> logs/vessel/${container}.log &
        fi
    done
fi
