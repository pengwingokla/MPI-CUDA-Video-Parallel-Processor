#!/usr/bin/env bash
set -e  # Exit on any error

echo "==> COMPILING MPI+CUDA VERSION..."
make full

echo "==> RUNNING MPI+CUDA VERSION..."
# This will save output of each rank in output/output_mpi_cuda/rank.X/stdout and stderr
mpirun -np 4 \
    --output-filename output/output_mpi_cuda/logs ./exec_full

echo "==> GENERATING VIDEO FROM PROCESSED FRAMES..."
ffmpeg -y -framerate 30 -i output/output_mpi_cuda/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p -crf 23 output_mpi_cuda.mp4
