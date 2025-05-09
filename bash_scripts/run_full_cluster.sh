#!/bin/bash
set -e

echo "==> COMPILING MPI+CUDA VERSION ON MASTER NODE..."
make full

echo "==> COPYING EXECUTABLE AND FRAMES TO WORKER NODE..."
scp -r ./exec_full ./frames include src utils.c frame_io.c cuda_filter.c task_queue.c user@node2:~/MPI-CUDA-Video-Parallel-Processor/

echo "==> RUNNING ON CLUSTER USING HOSTFILE..."
mpirun --hostfile my_hosts.txt --allow-run-as-root ./exec_full

echo "==> CONVERTING OUTPUT TO VIDEO..."
ffmpeg -y -framerate 30 -i output/output_mpi_cuda/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p output_mpi_cuda.mp4
