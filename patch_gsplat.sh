#!/bin/bash
set -eo pipefail

# Ensure we are in the right directory and it's not root
if [[ "$PWD" == "/" ]]; then
    echo "Error: Running in root directory!"
    exit 1
fi

find gsplat/cuda -maxdepth 3 -type f \( -name "*.cu" -o -name "*.cuh" -o -name "*.cpp" \) | while read -r file; do
    sed -i \
        -e "s/<float,64>/<float,32>/g" \
        -e "s/<float, 64>/<float, 32>/g" \
        -e "s/<int32_t, 64>/<int32_t, 32>/g" \
        -e "s/thread_block_tile<64>/thread_block_tile<32>/g" \
        -e "s/tiled_partition<64>/tiled_partition<32>/g" \
        -e "s/LOGICAL_WARP_SIZE = 64/LOGICAL_WARP_SIZE = 32/g" \
        -e "s/(block_size + 63) \/ 64/(block_size + 31) \/ 32/g" \
        -e "s/% 64/% 32/g" \
        -e "s/%64/%32/g" \
        -e "s/\/64/\/32/g" \
        -e "s/\/ 64/\/ 32/g" \
        -e "s/k+=64/k+=32/g" \
        -e "s/i < 64/i < 32/g" \
        -e "s/rocprim_warpSum<CDIM, 64>/rocprim_warpSum<CDIM, 32>/g" \
        -e "s/rocprim_warpSum<3, 64>/rocprim_warpSum<3, 32>/g" \
        -e "s/rocprim_warpSum<64>/rocprim_warpSum<32>/g" \
        -e "s/block_size == 64/block_size == 32/g" \
        -e "s/__launch_bounds__(64)/__launch_bounds__(32)/g" \
        -e "s/block.dim_threads()/block.dim_block()/g" \
        -e "s/#include \"device_launch_parameters.h\"/\/\/ #include \"device_launch_parameters.h\"/g" \
        -e "s/__trap()/\/\/ __trap()/g" \
        "$file"
done

sed -i "s/def get_rocm_arch():/def get_rocm_arch():\n    return os.environ.get(\"PYTORCH_ROCM_ARCH\", \"gfx1151\")\ndef old_get_rocm_arch():/" setup.py
