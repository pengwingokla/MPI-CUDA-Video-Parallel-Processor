#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
#  MPI+CUDA Video Pipeline: End-to-End Runner
# ─────────────────────────────────────────────────────────────────────────────

# Colors for pretty output
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
BLUE=$(printf '\033[34m')
YELLOW=$(printf '\033[33m')
RESET=$(printf '\033[0m')

# ─── Configuration ────────────────────────────────────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIDEO="${1:-panda.mp4}"
TIMESTAMP=$(date +'%Y%m%d-%H%M%S')
LOGDIR="$ROOT/logs/run_${TIMESTAMP}"
FRAMES="$ROOT/frames"
OUT="$ROOT/output"

mkdir -p "$LOGDIR" "$FRAMES" "$OUT"

log() {
  echo -e "[${BLUE}$(date +'%H:%M:%S')${RESET}] $*"
}

# ─── Utility: time a step and log duration ─────────────────────────────────────
time_step() {
  local desc=$1; shift
  local slug=$(echo "$desc" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
  log "→ ${YELLOW}${desc}${RESET}"
  local start=$(date +%s)
  if ! "$@" 2>&1 | tee "$LOGDIR/${slug}.log"; then
    echo -e "${RED}✖ Step failed: $desc${RESET}"
    exit 1
  fi
  local end=$(date +%s)
  log "✔ ${desc} completed in $((end - start))s"
  echo
}

# ─── Step 0: Build all executables ──────────────────────────────────────────────
time_step "Building all executables" make -j"$(nproc)"

# ─── Step 1: Extract frames ────────────────────────────────────────────────────
if compgen -G "$FRAMES/frame_*.jpg" >/dev/null; then
  count=$(ls "$FRAMES"/frame_*.jpg | wc -l)
  log "→ ${GREEN}Found existing frames:${RESET} $count"
else
  time_step "Extracting frames" ffmpeg -y -i "$ROOT/$VIDEO" "$FRAMES/frame_%04d.jpg"
  count=$(ls "$FRAMES"/frame_*.jpg | wc -l)
  log "→ ${GREEN}Extracted frames:${RESET} $count"
fi

# ─── Step 2: Serial version ─────────────────────────────────────────────────────
mkdir -p "$OUT/serial"
time_step "Running Serial" "$ROOT/exec/exec_serial" "$FRAMES" "$OUT/serial"
time_step "Serial → Making video" \
  ffmpeg -y -framerate 30 -i "$OUT/serial/frame_%04d.jpg" \
    -c:v libx264 -pix_fmt yuv420p "$OUT/serial.mp4"

# ─── Step 3: MPI-only version ──────────────────────────────────────────────────
mkdir -p "$OUT/mpi"
time_step "Running MPI-only" \
  mpirun --oversubscribe -np 4 "$ROOT/exec/exec_mpi_only" "$FRAMES" "$OUT/mpi"
time_step "MPI-only → Making video" \
  ffmpeg -y -framerate 30 -i "$OUT/mpi/frame_%04d.jpg" \
    -c:v libx264 -pix_fmt yuv420p "$OUT/mpi.mp4"

# ─── Step 4: CUDA-only version ─────────────────────────────────────────────────
mkdir -p "$OUT/cuda"
time_step "Running CUDA-only" "$ROOT/exec/exec_cuda_only" "$FRAMES" "$OUT/cuda"
time_step "CUDA-only → Making video" \
  ffmpeg -y -framerate 30 -i "$OUT/cuda/frame_%04d.jpg" \
    -c:v libx264 -pix_fmt yuv420p "$OUT/cuda.mp4"

# ─── Step 5: MPI+CUDA version ───────────────────────────────────────────────────
mkdir -p "$OUT/mpi_cuda"
time_step "Running MPI+CUDA" \
  mpirun --oversubscribe -np 8 "$ROOT/exec/exec_full" "$FRAMES" "$OUT/mpi_cuda"
time_step "MPI+CUDA → Making video" \
  ffmpeg -y -framerate 30 -i "$OUT/mpi_cuda/frame_%04d.jpg" \
    -c:v libx264 -pix_fmt yuv420p "$OUT/mpi_cuda.mp4"

# ─── Done! ─────────────────────────────────────────────────────────────────────
log "${GREEN}✅ All steps completed successfully!${RESET}"
log "  • Logs:   $LOGDIR"
log "  • Videos:"
log "      Serial:    $OUT/serial.mp4"
log "      MPI-only:  $OUT/mpi.mp4"
log "      CUDA-only: $OUT/cuda.mp4"
log "      MPI+CUDA:  $OUT/mpi_cuda.mp4"

exit 0
