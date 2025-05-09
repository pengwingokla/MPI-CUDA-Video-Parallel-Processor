#!/usr/bin/env bash
set -euo pipefail

# scrape_project.sh
# -----------------
# Collects all the key project files into a single text file,
# with each file’s contents wrapped in Markdown-style code fences.

OUTPUT=${1:-project_snapshot.txt}
> "$OUTPUT"

# List of “relevant” files and directories to include
FILES=(
  "shell.nix"
  "Makefile"
  "run_all.sh"
  "bash_scripts/v1_serial.sh"
  "bash_scripts/v2_mpi.sh"
  "bash_scripts/v3_cuda.sh"
  "bash_scripts/v4_full.sh"
  "src/extract_frames.py"
  "src/main_serial.c"
  "src/main_mpi.c"
  "src/main_cuda.c"
  "src/main_mpi_cuda.c"
  "src/master.c"
  "src/task_queue.c"
  "src/utils.c"
  "src/worker_cuda.c"
  "include/cuda_filter.h"
  "include/cuda_segmentation.h"
  "include/frame_io.h"
  "include/stb_image_write.h"
#   "include/stb_image.h"
  "include/task_queue.h"
  "include/utils.h"
)

for path in "${FILES[@]}"; do
  # Expand any globs (e.g. src/*.c) and skip missing
  for file in $path; do
    [[ -f "$file" ]] || continue

    echo "### File: $file" >> "$OUTPUT"
    echo '```'       >> "$OUTPUT"
    cat "$file"      >> "$OUTPUT"
    echo '```'       >> "$OUTPUT"
    echo            >> "$OUTPUT"
  done
done

echo "✔ Written project snapshot to '$OUTPUT'"
