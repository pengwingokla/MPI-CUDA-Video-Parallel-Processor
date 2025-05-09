Thought for a second


# QuickStart Guide for MPI+CUDA Video Processing Pipeline

Welcome! This guide will walk you through setting up, building, and running the **MPI+CUDA Video Pipeline** on NixOS (or any system using Nix), using the provided `shell.nix`, `run_all.sh`, and project sources. By the end, you will have extracted frames from your video, processed them in four different modes (serial, MPI-only, CUDA-only, and MPI+CUDA hybrid), and reassembled the outputs into playable videos.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Layout](#project-layout)
3. [Enter the Development Shell](#enter-the-development-shell)
4. [Building the Code](#building-the-code)
5. [Patching Binaries on NixOS](#patching-binaries-on-nixos)
6. [Running End-to-End with `run_all.sh`](#running-end-to-end-with-run_allsh)
7. [Per-Component Manual Execution](#per-component-manual-execution)
8. [Troubleshooting Tips](#troubleshooting-tips)
9. [Understanding the Pipeline](#understanding-the-pipeline)
10. [Extending & Customizing](#extending--customizing)

---

## Prerequisites

* **Nix** + **NixOS** (tested on NixOS 24.11+).
* NVIDIA GPU with a recent driver supporting CUDA 12.x.
* Internet connectivity (for initial Nix package downloads).

---

## Project Layout

```
.
├── bash_scripts/         # Legacy per-version helpers
├── build/                # .o files (auto-created)
├── exec/                 # Patched executables (populated after `make` + patch)
├── frames/               # JPEG frames extracted from video
├── include/              # Header files
├── logs/                 # Run logs (auto-created)
├── output/               # Processed frames & final .mp4 outputs
├── src/                  # C / CUDA / MPI / Python sources
├── shell.nix             # Nix development shell
├── run_all.sh            # End-to-end runner script
├── scrape_project.sh     # Snapshot script
├── Makefile              # Top-level build rules
└── panda.mp4             # Example input video
```

* **`shell.nix`** defines a lightweight Nix shell with `gcc`, `openmpi`, `cudaToolkit`, `ffmpeg`, and a Python 3 environment with OpenCV.
* **`Makefile`** builds four executables:

  * `exec_serial`
  * `exec_mpi_only`
  * `exec_cuda_only`
  * `exec_full` (MPI+CUDA hybrid)
* **`run_all.sh`** invokes all four executables in sequence, logs output, and reassembles processed frames via `ffmpeg`.
* **`src/`** contains:

  * C implementations for serial, MPI, CUDA, and hybrid versions
  * Python `extract_frames.py` to split a video into `frames/frame_XXXX.jpg`

---

## Enter the Development Shell

1. **Open a terminal** and navigate to the project root.

2. Run:

   ```bash
   nix-shell
   ```

3. On entry, you should see something like:

   ```
   --- Nix Shell for MPI+CUDA Video Pipeline ---
   C Compiler: gcc (GCC) 13.3.0 ...
   MPI: mpicc (Open MPI) ...
   CUDA: Cuda compilation tools, release 12.4, V12.4.99
   FFmpeg: ...
   Python3: Python 3.x.x
     Modules: cv2 -> 4.x.x
   ```

4. This shell provides:

   * `gcc`, `mpicc`, `nvcc`
   * `ffmpeg`
   * `python3` with `import cv2`
   * `make`

---

## Building the Code

Inside the Nix shell:

```bash
# Clean any previous build artifacts
make clean

# Build all four executables in parallel
make -j"$(nproc)"

# Copy them into exec/
mkdir -p exec
cp exec_serial exec/exec_serial
cp exec_mpi_only exec/exec_mpi_only
cp exec_cuda_only exec/exec_cuda_only
cp exec_full exec/exec_full
```

You should now have `exec/exec_serial`, `exec/exec_mpi_only`, `exec/exec_cuda_only`, and `exec/exec_full`.

---

## Patching Binaries on NixOS

By default, dynamically linked binaries built in Nix cannot run outside the store without help. We patch them to embed the correct loader and rpath:

1. **Discover locations**:

   ```bash
   LOADER=$(find /nix/store -type f -path '*-glibc-*/lib/ld-linux-x86-64.so.2' | head -n1)
   GLIBC_LIB=$(dirname "$LOADER")
   MPI_LIB=$(dirname "$(find /nix/store -type f -path '*openmpi-*/lib/libmpi.so' | head -n1)")
   NVCC_LIB=$(dirname "$(find /nix/store -type f -path '*cuda_nvcc-*/lib64/libnvvm.so' | head -n1)")
   CUDART_LIB=$(dirname "$(find /nix/store -type f -path '*cuda*toolkit*/lib/libcudart.so.12*' | head -n1)")
   ```

2. **Patch each executable**:

   ```bash
   for BIN in exec/exec_serial exec/exec_mpi_only exec/exec_cuda_only exec/exec_full; do
     patchelf --set-interpreter "$LOADER" "$BIN"
     patchelf --set-rpath "$GLIBC_LIB:$MPI_LIB:$NVCC_LIB:$CUDART_LIB" "$BIN"
   done
   ```

3. **Verify**:

   ```bash
   readelf -l exec/exec_serial | grep 'Requesting program interpreter'
   readelf -d exec/exec_serial | grep RUNPATH
   ```

---

## Running End-to-End with `run_all.sh`

Once patched, simply run:

```bash
chmod +x run_all.sh
./run_all.sh [optional_video.mp4]
```

* **First argument** is the input video (defaults to `panda.mp4` if omitted).
* The script will:

  1. **Build** all four versions (`make -j…`)
  2. **Extract** frames (if not already present)
  3. **Run** Serial → MPI-only → CUDA-only → MPI+CUDA
  4. **Reassemble** frames into four videos under `output/`
  5. **Log** each step to `logs/run_<timestamp>/` with detailed timing

At the end, you’ll see:

```
✅ All steps completed successfully!
  • Logs:   logs/run_20250508-214530
  • Videos:
      Serial:    output/serial.mp4
      MPI-only:  output/mpi.mp4
      CUDA-only: output/cuda.mp4
      MPI+CUDA:  output/mpi_cuda.mp4
```

---

## Per-Component Manual Execution

If you want to run each version in isolation:

1. **Serial**

   ```bash
   ./exec/exec_serial frames output/serial
   ffmpeg -y -framerate 30 -i output/serial/frame_%04d.jpg -c:v libx264 output/serial.mp4
   ```

2. **MPI-only**

   ```bash
   mpirun --oversubscribe -np 4 ./exec/exec_mpi_only frames output/mpi
   ffmpeg -y -framerate 30 -i output/mpi/frame_%04d.jpg -c:v libx264 output/mpi.mp4
   ```

3. **CUDA-only**

   ```bash
   ./exec/exec_cuda_only frames output/cuda
   ffmpeg -y -framerate 30 -i output/cuda/frame_%04d.jpg -c:v libx264 output/cuda.mp4
   ```

4. **MPI+CUDA**

   ```bash
   mpirun --oversubscribe -np 8 ./exec/exec_full frames output/mpi_cuda
   ffmpeg -y -framerate 30 -i output/mpi_cuda/frame_%04d.jpg -c:v libx264 output/mpi_cuda.mp4
   ```

---

## Troubleshooting Tips

* **“cannot open shared object file”**: Re-run the Patchelf steps to embed the correct loader and library paths.
* **Zero frames extracted**: Ensure your input video path is correct, and OpenCV/GStreamer in nix-shell can read it. Try converting your video to a standard H.264 format.
* **MPI processes hang**: Check for firewall settings blocking loopback communication. Use `--oversubscribe` and `--allow-run-as-root` if necessary.
* **CUDA errors**: Verify your GPU drivers support the requested CUDA version (`nvidia-smi`), and that `nvcc --version` in nix-shell matches.

---

## Understanding the Pipeline

1. **Frame Extraction**

   * Python+OpenCV script splits the input `.mp4` into `frames/frame_XXXX.jpg`.
2. **Serial Version**

   * C program loops over all frames, applies a simple CPU-only edge filter, writes output JPEGs.
3. **MPI-only Version**

   * Master/worker model in C: distributes frame indices among N MPI ranks, each does the same CPU-only filter.
4. **CUDA-only Version**

   * Single process uses `nvcc`-compiled kernels to run the edge filter on the GPU for each frame.
5. **MPI+CUDA Hybrid**

   * Combines MPI for distributing frame tasks across ranks with CUDA kernels on each rank for per-frame GPU acceleration, plus optional temporal linking.

---

## Extending & Customizing

* **Algorithm swap**: Modify `src/simple_edge_filter` or supply your own CUDA kernels in `src/cuda_filter.cu`.
* **Frame I/O**: Swap out STB image I/O for OpenCV’s C++ API by editing `include/frame_io.h` and `src/frame_io.c`.
* **Video parameters**: Change framerate, codec, resolution in the `ffmpeg` commands within `run_all.sh`.
* **Scaling to multi-node clusters**: Adjust `mpirun` hostfiles and process counts.

---

You’re all set! 🚀 Enjoy experimenting with hybrid **MPI + CUDA** video processing on NixOS. If you run into issues, consult the logs under `logs/`, verify library paths, and feel free to iterate on the Nix shell or `patchelf` commands. Have fun!
