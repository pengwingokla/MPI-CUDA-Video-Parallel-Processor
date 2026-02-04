# Parallel Video Frame Processing using MPI + CUDA

This project demonstrates how to build a **distributed GPU-accelerated image processing pipeline** using **MPI (Message Passing Interface)** and **CUDA (Compute Unified Device Architecture)**. It processes thousands of video frames in parallel by distributing tasks across processes (MPI) and accelerating computation per frame on the GPU (CUDA).

## Overview

This project implements a video processing pipeline with **four different versions**, each demonstrating different parallelization approaches:

1. **Serial Version** (`exec_serial`) - Single-threaded CPU processing, serves as the baseline implementation
2. **CUDA-Only Version** (`exec_cuda_only`) - GPU-accelerated processing using CUDA kernels for parallel frame processing
3. **MPI-Only Version** (`exec_mpi_only`) - Distributed processing using MPI to parallelize across multiple CPU processes
4. **MPI+CUDA Hybrid Version** (`exec_full`) - Combines MPI for distributed processing with CUDA for GPU acceleration on each node

By executing the code, you will have extracted frames from your video, processed them using all four versions, and reassembled the outputs into playable videos for comparison.

## What This Project Does

- Extracts frames from a video (done via a Python script using OpenCV).
- Distributes frame-processing tasks across **multiple MPI workers**.
- Each worker loads a frame, sends it to **CUDA on GPU** to **invert its colors**.
- The processed frame is saved.
- When all frames are processed, they can be reassembled into a new video using FFmpeg.

This setup is ideal for learning hybrid parallel programming that combines CPU task scheduling with GPU computation.

---

## Tech Stack

- **C (MPI)** for parallel task distribution
- **CUDA** for GPU image inversion
- **stb_image / stb_image_write** for image I/O
- **OpenCV (Python)** for frame extraction (optional)
- **FFmpeg** for video reconstruction (optional)

---

## Project Structure

mpi-project/
<br>├── src/
<br>│   ├── main_serial.c         # Serial version
<br>│   ├── main_cuda.cu          # CUDA-only
<br>│   ├── main_mpi.c            # MPI-only
<br>│   ├── main_mpi_cuda.cu      # MPI + CUDA
<br>│   ├── master.c              # MPI master logic
<br>│   ├── task_queue.c          # Simple task scheduler for MPI
<br>│   ├── cuda_filter.cu        # Filtering kernels
<br>│   ├── frame_io.c/h          # Image I/O
<br>│   ├── utils.c/h             # Utility helpers
<br>├── include/            
<br>│   ├── cuda_filter.h
<br>│   ├── frame_io.h
<br>│   ├── task_queue.h
<br>│   └── utils.h
<br>├── frames/                  # Input frames
<br>├── output/                  # Processed output
<br>├── bash_scripts/            # Demo scripts
<br>├── extract_frames.py        # Split video into frames
<br>└── Makefile


---

## How It Works

### Step 1: Master-Worker Model (MPI)

- The **master (rank 0)** loads all available image filenames into a task queue.
- Each **worker (rank > 0)** sends a task request to the master.
- The master sends a frame path to the worker.
- The worker processes the frame and returns a result log.

This continues until all frames are processed.

### Step 2: Per-Frame GPU Processing (CUDA)

Each frame is passed to a CUDA kernel that performs **color inversion**: `output_pixel = 255 - input_pixel`

This is done in parallel for each pixel using GPU threads.

### Step 3: Reconstruct Video

Once all frames are processed, `FFmpeg` can be used to stitch them into a video:
```bash
ffmpeg -framerate 30 -i output/frame_%04d.jpg -c:v libx264 output.mp4
```
## Installation & Build
#### Please visit `SIMPLE_INSTRUCTION.md` for a more straightforward instrction

##  Build
To elaborate further, these are the commands in the bash scripts. Note that this only works after frames from the video were extracted and contained in the `/frames` folder.
#### Version 1: Serial (no MPI, no CUDA)
```
./exec_serial
```
#### Version 2: MPI-only
```
.mpirun -np 4 ./exec_mpi_only
```
#### Version 3: CUDA-only
```
./exec_cuda_only
```
#### Version 4: MPI + CUDA (multi-node or multi-GPU)
```
mpirun -np 8 ./exec_full
```

## 📦 Output
Each processed frame will be saved to output/frame_XXXX.jpg.

The output images will be the color-inverted versions of the input frames.

## How MPI + CUDA Work Together

MPI Master: Distributes frame tasks to workers
MPI Worker: Receives frame path, processes it
CUDA Kernel: Inverts pixel values on GPU
Task Queue: Dynamically assigns frames as they are available

## Credits
<br>[stb_image](https://github.com/nothings/stb)
<br>[OpenCV](https://opencv.org/)
<br>[OpenMPI](https://www.open-mpi.org/)
<br>NVIDIA CUDA Toolkit