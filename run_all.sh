#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
#  MPI+CUDA Video Pipeline: Runner Using bash_scripts/*.sh
# ─────────────────────────────────────────────────────────────────────────────

# Colors
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
BLUE=$(printf '\033[34m')
YELLOW=$(printf '\033[33m')
RESET=$(printf '\033[0m')

# Paths
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$ROOT/bash_scripts"
LOGROOT="$ROOT/logs"
TIMESTAMP=$(date +'%Y%m%d-%H%M%S')
LOGDIR="$LOGROOT/run_$TIMESTAMP"
mkdir -p "$LOGDIR"

# Helper to print bold-ish timestamped messages
log() {
  echo -e "[${BLUE}$(date +'%H:%M:%S')${RESET}] $*"
}

# Helper to time & log each step
time_step() {
  local desc="$1"; shift
  local slug
  slug="$(echo "$desc" | tr ' [:upper:]' '_[:lower:]')"
  log "→ ${YELLOW}$desc${RESET}"
  local start end
  start=$(date +%s)
  if ! bash -c "$*" 2>&1 | tee "$LOGDIR/${slug}.log"; then
    echo -e "${RED}✖ $desc failed. See log:${RESET} $LOGDIR/${slug}.log"
    exit 1
  fi
  end=$(date +%s)
  log "✔ $desc completed in $((end - start))s"
  echo
}

# ─── Step 1: Build all binaries ────────────────────────────────────────────────
time_step "Build all executable targets" "make -j\$(nproc) serial mpi_only cuda_only full"

# ─── Step 2: Patch root binaries for NixOS ────────────────────────────────────
time_step "Patch binaries for NixOS stdenv" '
  # find the loader & lib dirs
  LOADER=$(find /nix/store -type f -path "*-glibc-*/lib/ld-linux-x86-64.so.2" | head -n1)
  GLIBC_LIB=$(dirname "$LOADER")
  MPI_LIB=$(dirname "$(find /nix/store -type f -path "*openmpi-*/lib/libmpi.so" | head -n1)")
  CUDART_LIB=$(dirname "$(find /nix/store -type f -path "*cudatoolkit-*/lib/libcudart.so"* | head -n1)")
  # patch each binary in project root
  for BIN in exec_serial exec_mpi_only exec_cuda_only exec_full; do
    FULL=\"$ROOT/\$BIN\"
    patchelf --set-interpreter \"$LOADER\" \
             --set-rpath \"$GLIBC_LIB:$MPI_LIB:$CUDART_LIB\" \
             \"\$FULL\"
  done
'

# ─── Step 3: Run each version via your bash_scripts ──────────────────────────

time_step "Version 1: Serial"        "bash \"$SCRIPTS/v1_serial.sh\""
time_step "Version 2: MPI-only"      "bash \"$SCRIPTS/v2_mpi.sh\""
time_step "Version 3: CUDA-only"     "bash \"$SCRIPTS/v3_cuda.sh\""
time_step "Version 4: MPI+CUDA"      "bash \"$SCRIPTS/v4_full.sh\""

# ─── Done! ─────────────────────────────────────────────────────────────────────
log "${GREEN}✅ All steps completed successfully!${RESET}"
log "  • Logs directory: $LOGDIR"
exit 0
