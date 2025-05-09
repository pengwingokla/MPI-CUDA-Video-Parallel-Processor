#!/usr/bin/env bash

set -e

echo "==> SETTING UP PYTHON VIRTUAL ENVIRONMENT..."
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

echo "==> EXTRACTING FRAMES..."
python3 src/extract_frames.py
mkdir output/
mkdir output/output_cuda/

echo "==> COMPILING CUDA-ONLY VERSION..."
make cuda_only

echo "==> RUNNING CUDA-ONLY VERSION..."
./exec_cuda_only

echo "==> GENERATING VIDEO FROM FRAMES..."
ffmpeg -y -framerate 30 -i output/output_cuda/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p output_cuda.mp4
