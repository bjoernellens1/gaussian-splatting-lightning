#!/bin/bash
set -eo pipefail

# Ensure we are in the right directory and it's not root
if [[ "$PWD" == "/" ]]; then
    echo "Error: Running in root directory!"
    exit 1
fi

find . -maxdepth 4 -type f \( -name "*.cu" -o -name "*.cuh" -o -name "*.cpp" -o -name "*.hip" \) | while read -r file; do
    sed -i \
        -e "s/#include \"device_launch_parameters.h\"/\/\/ #include \"device_launch_parameters.h\"/g" \
        -e "s/#include <cooperative_groups\/reduce.h>/\/\/ #include <cooperative_groups\/reduce.h>/g" \
        -e "s/#define __HIPCC__/\/\/ #define __HIPCC__/g" \
        -e "1i #include <cfloat>" \
        -e "s/coord2Morton << <(P + 255) \/ 256, 256 >> > (P, points, minn, maxx, morton.data().get());/hipLaunchKernelGGL(coord2Morton, dim3((P + 255) \/ 256), dim3(256), 0, 0, P, points, minn, maxx, morton.data().get());/g" \
        -e "s/boxMinMax << <num_boxes, BOX_SIZE >> > (P, points, indices_sorted.data().get(), boxes.data().get());/hipLaunchKernelGGL(boxMinMax, dim3(num_boxes), dim3(BOX_SIZE), 0, 0, P, points, indices_sorted.data().get(), boxes.data().get());/g" \
        -e "s/boxMeanDist << <num_boxes, BOX_SIZE >> > (P, points, indices_sorted.data().get(), boxes.data().get(), meanDists);/hipLaunchKernelGGL(boxMeanDist, dim3(num_boxes), dim3(BOX_SIZE), 0, 0, P, points, indices_sorted.data().get(), boxes.data().get(), meanDists);/g" \
        "$file"
done
