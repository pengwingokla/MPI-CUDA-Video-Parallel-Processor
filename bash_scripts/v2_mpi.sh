#!/usr/bin/env bash
set -e

echo "==> CLEANING..."
make clean

echo "==> COMPILING MPI-ONLY VERSION..."
make mpi_only

echo "==> RUNNING MPI-ONLY VERSION..."
mpirun -np 4 \
    --output-filename output/output_mpi/logs ./exec_mpi_only

# echo "==> CONVERTING FRAMES TO VIDEO..."
# ffmpeg -y -framerate 30 -i output/output_mpi/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p output_mpi_only.mp4
