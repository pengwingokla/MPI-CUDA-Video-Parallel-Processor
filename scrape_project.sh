#!/usr/bin/env bash

# Define the list of files and directories provided.
# In a real scenario, you might get this from a file or command output.
# This script assumes it's running in the root directory where these paths are valid.
FILE_ENTRIES=$(cat << 'EOF'
bash_scripts
bash_scripts/run_full_cluster.sh
bash_scripts/v1_serial.sh
bash_scripts/v2_mpi.sh
bash_scripts/v3_cuda.sh
bash_scripts/v4_full.sh
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
exec
exec/exec_cuda_only
exec/exec_full
exec/exec_mpi_only
exec/exec_serial
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
cappy.mp4
cappy.mp4:Zone.Identifier
CLEANING...
COMPILING
cuda_filter.o
exec_cuda
exec_cuda_only
exec_full
exec_serial
frame_io.o
main_mpi_cuda.o
Makefile
master.o
myhost.txt
output_serial.mp4
panda.mp4:Zone.Identifier
project_setup.sh
project_snapshot.txt
QUICKSTART.md
README.md
requirements.txt
run_all.sh
scrape_project.sh
shell.nix
SIMPLE_INSTRUCTION.md
task_queue.o
test_segment
test_segment_label
test_segment.o
utils.o
worker_cuda.o
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
       [[ "$entry" == exec/* ]] || \
       [[ "$entry" == *.o ]] || \
       [[ "$entry" == *.mp4 ]] || \
       [[ "$entry" == *.mp4:Zone.Identifier ]] || \
       [[ "$entry" == *.txt ]] || \
       [[ "$entry" == *.md ]] || \
       [[ "$entry" == ".gitignore" ]] || \
       [[ "$entry" == "shell.nix" ]] || \
       [[ "$entry" == "cappy.mp4:Zone.Identifier" ]] || \
       [[ "$entry" == "panda.mp4:Zone.Identifier" ]]; then
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