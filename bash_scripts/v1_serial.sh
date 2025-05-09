#!/usr/bin/env bash

set -e  # Stop on first error

echo "==> SETTING UP PYTHON VIRTUAL ENVIRONMENT..."
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

echo "==> EXTRACTING FRAMES..."
python3 src/extract_frames.py
mkdir output/
mkdir output/output_serial/

echo "==> CLEANING..."
make clean

echo "==> COMPILING SERIAL VERSION..."
make serial

echo "==> RUNNING SERIAL VERSION..."
./exec_serial

echo "==> CONVERTING FRAMES TO VIDEO..."
ffmpeg -y -framerate 10 -i output/output_serial/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p output_serial.mp4
