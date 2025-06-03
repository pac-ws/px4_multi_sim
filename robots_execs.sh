#!/usr/bin/env bash

PX4_DIR="/opt/px4_ws/src/PX4-Autopilot"
filename=${1}

if [[ ! -r "$filename" ]]; then
    echo "Cannot read file: $filename"
    exit 1
fi

while read -r line; do
    if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue
    fi

    line=$(echo "$line" | xargs)
    read -r id x y heading <<< "$line"
    PX4_GZ_STANDALONE=1 PX4_GZ_MODEL_POSE="${x},${y},0.10,0,0,${heading}" ${PX4_DIR}/build/px4_sitl_default/bin/px4 -i $id > /dev/null &
    sleep 0.1

done < "$filename"

wait
