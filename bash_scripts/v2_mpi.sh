#!/usr/bin/env bash
set -e

echo "==> SETTING UP PYTHON VIRTUAL ENVIRONMENT..."
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

echo "==> EXTRACTING FRAMES..."
python3 src/extract_frames.py

mkdir -p output/output_mpi/

echo "==> CLEANING..."
make clean

echo "==> COMPILING MPI-ONLY VERSION..."
make mpi_only

echo "==> RUNNING MPI-ONLY VERSION..."
mpirun -np 8 \
    --allow-run-as-root \
    --output-filename output/output_mpi/logs ./exec_mpi_only

echo "==> CONVERTING FRAMES TO VIDEO..."
ffmpeg -y -framerate 30 -i output/output_mpi/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p output_mpi_only.mp4
