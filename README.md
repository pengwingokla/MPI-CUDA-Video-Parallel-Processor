# Parallel Video Frame Processing using MPI + CUDA

This project demonstrates how to build a **distributed GPU-accelerated image processing pipeline** using **MPI (Message Passing Interface)** and **CUDA (Compute Unified Device Architecture)**. It processes thousands of video frames in parallel by distributing tasks across processes (MPI) and accelerating computation per frame on the GPU (CUDA).

---

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

`mpi-project`/ 
<br>├── `main.c` # MPI entry point 
<br>├── `master.c` # Master process: distributes tasks 
<br>├── `worker.c` # Worker process: loads & processes frames 
<br>├── `frame_io.c/h` # Handles image loading/saving (via stb) 
<br>├── task_queue.c/h # Maintains list of image frames 
<br>├── `cuda_filter.cu` # CUDA kernel for image inversion 
<br>├── `extract_frames.py` # Python script to split video into frames 
<br>├── output/ # Processed output frames 
<br>├── frames/ # Input frames (from extract script) 
<br>└── `Makefile`

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
Install Required Packages
```bash
sudo apt update
sudo apt install build-essential libopenmpi-dev openmpi-bin ffmpeg python3 python3-pip
pip install opencv-python
```
Extract Video Frames
```
python3 extract_frames.py input.mp4
```
Build the Project
```
make
```
Run the Project
```
mpirun --allow-run-as-root -np 4 ./classifier
```
Check if output frames match input frames
```
ls output/ | wc -l  # Should match number of input frames
```
Combine the processed frames to a video
```
ffmpeg -framerate 30 -i output/frame_%04d.jpg -c:v libx264 -pix_fmt yuv420p sobel_output.mp4
```

##  Build Instructions

### Version 1: Serial (no MPI, no CUDA)
```
./exec_serial
```
### Version 2: MPI-only
```
.mpirun -np 4 ./exec_mpi_only
```
### Version 3: CUDA-only
```
./exec_cuda_only
```
### Version 4: MPI + CUDA (multi-node or multi-GPU)
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