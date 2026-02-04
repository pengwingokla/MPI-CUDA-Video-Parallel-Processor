#!/usr/bin/env bash

# Define the list of files and directories provided.
# In a real scenario, you might get this from a file or command output.
# This script assumes it's running in the root directory where these paths are valid.
FILE_ENTRIES=$(cat << 'EOF'
scripts
scripts/run_full_cluster.sh
scripts/v1_serial.sh
scripts/v2_mpi.sh
scripts/v3_cuda.sh
scripts/v4_full.sh
scripts/run_all.sh
scripts/project_setup.sh
scripts/scrape_project.sh
build/obj
build/obj/cuda_filter.o
build/obj/frame_io_serial.o
build/obj/frame_io.o
build/obj/main_cuda.o
build/obj/main_mpi_cuda.o
build/obj/main_serial.o
build/obj/master.o
build/obj/task_queue.o
build/obj/utils_serial.o
build/obj/utils.o
build/obj/worker_cuda.o
build/obj/test_segment.o
bin
bin/exec_cuda
bin/exec_cuda_only
bin/exec_full
bin/exec_mpi_only
bin/exec_serial
bin/test_segment
bin/test_segment_label
data/videos
data/videos/cappy.mp4
data/videos/cappy.mp4:Zone.Identifier
data/videos/panda.mp4:Zone.Identifier
data/output
data/output/output_serial.mp4
config
config/myhost.txt
frames
include
include/cuda_filter.h
include/cuda_segmentation.h
include/frame_io.h
include/stb_image_write.h
include/stb_image.h
include/task_queue.h
include/utils.h
logs
output
output/output_mpi
output/output_mpi_cuda
src
src/cuda_filter.cu
src/extract_frames.py
src/frame_io_serial.c
src/frame_io.c
src/main_cuda.c
src/main_mpi_cuda.c
src/main_mpi.c
src/main_serial.c
src/master.c
src/task_queue.c
src/utils.c
src/worker_cuda.c
venv
.gitignore
Makefile
project_snapshot.txt
QUICKSTART.md
README.md
requirements.txt
shell.nix
SIMPLE_INSTRUCTION.md
EOF
)

MAX_LINES=250

echo "$FILE_ENTRIES" | while IFS= read -r entry; do
    # Trim potential leading/trailing whitespace from the entry
    entry=$(echo "$entry" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Skip if entry is empty after trimming
    if [ -z "$entry" ]; then
        continue
    fi

    # 1. Check if it's an actual file on the filesystem
    #    This will filter out directory names like 'src', 'include', 'build/obj'
    #    and also placeholder text like 'CLEANING...', 'COMPILING'
    if [ ! -f "$entry" ]; then
        # For debugging: echo "Skipping non-file or non-existent: $entry" >&2
        continue
    fi

    # 2. Exclude specific directories, file types, and individual files
    #    we know are not relevant source code.
    if [[ "$entry" == build/obj/* ]] || \
       [[ "$entry" == bin/* ]] || \
       [[ "$entry" == data/* ]] || \
       [[ "$entry" == config/* ]] || \
       [[ "$entry" == *.o ]] || \
       [[ "$entry" == *.mp4 ]] || \
       [[ "$entry" == *.mp4:Zone.Identifier ]] || \
       [[ "$entry" == *.txt ]] || \
       [[ "$entry" == *.md ]] || \
       [[ "$entry" == ".gitignore" ]] || \
       [[ "$entry" == "shell.nix" ]]; then
        # For debugging: echo "Skipping excluded pattern: $entry" >&2
        continue
    fi

    # 3. Identify relevant source code files by extension or specific name
    is_source_code=false
    case "$entry" in
        *.c|*.h|*.cu|*.py|*.sh) # Common source/script extensions
            is_source_code=true
            ;;
        Makefile) # Specific filename
            is_source_code=true
            ;;
        # Add other relevant extensions if needed, e.g., *.cpp, *.java, *.js
        *)
            # For debugging: echo "Skipping non-source extension: $entry" >&2
            ;;
    esac

    if [ "$is_source_code" = true ]; then
        echo "--- START FILE: $entry ---"
        # Use head to get up to MAX_LINES.
        # If file has fewer lines, head will just output all of them.
        head -n "$MAX_LINES" "$entry"
        echo "--- END FILE: $entry ---"
        echo "" # Add a blank line for better readability between files
    fi
done

echo "Scraping complete."