#!/usr/bin/env bash
set -e  # Exit on any error

echo "==> SETTING UP PYTHON VIRTUAL ENVIRONMENT..."
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

echo "==> EXTRACTING FRAMES..."
python3 src/extract_frames.py

echo "==> COMPILING MPI+CUDA VERSION..."
make full

echo "==> RUNNING MPI+CUDA VERSION..."
# This will save output of each rank in output/output_mpi_cuda/rank.X/stdout and stderr
mpirun -np 4 --allow-run-as-root\
    --output-filename output/output_mpi_cuda/logs ./exec_full

echo "==> GENERATING VIDEO FROM PROCESSED FRAMES..."
ffmpeg -y -framerate 30 -i output/output_mpi_cuda/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p -crf 23 output_mpi_cuda.mp4
