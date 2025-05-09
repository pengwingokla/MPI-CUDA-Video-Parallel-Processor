#!/usr/bin/env bash

set -e

echo "==> COMPILING CUDA-ONLY VERSION..."
make cuda_only

echo "==> RUNNING CUDA-ONLY VERSION..."
./exec_cuda_only

echo "==> GENERATING VIDEO FROM FRAMES..."
ffmpeg -y -framerate 30 -i output/output_cuda/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p output_cuda.mp4
