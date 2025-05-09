#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Project Structure Setup ---
FRAMES_DIR="frames"
OUTPUT_DIR="output"
BASH_SCRIPTS_DIR="bash_scripts"

echo "[PROJECT] Ensuring directory structure..."
mkdir -p "$FRAMES_DIR"
mkdir -p "$OUTPUT_DIR"
echo "[PROJECT] '$FRAMES_DIR' and '$OUTPUT_DIR' directories ensured."

if [ -d "$BASH_SCRIPTS_DIR" ]; then
  echo "[PROJECT] Making bash scripts in '$BASH_SCRIPTS_DIR/' executable..."
  chmod +x "$BASH_SCRIPTS_DIR"/*.sh
  echo "[PROJECT] Bash scripts are now executable."
else
  echo "[WARN] '$BASH_SCRIPTS_DIR' directory not found. Cannot make scripts executable."
fi

# --- Video File Check ---
VIDEO_FILE_CANDIDATE=$(find . -maxdepth 1 -iname "*.mp4" -print -quit 2>/dev/null)
if [ -n "$VIDEO_FILE_CANDIDATE" ]; then
    echo "[PROJECT] Found a video file: '$VIDEO_FILE_CANDIDATE'."
    echo "          Please ensure your 'src/extract_frames.py' script is configured to use your desired input video."
else
    echo "[WARN] No .mp4 video found in the project root. Make sure to add your video file"
    echo "         and update 'src/extract_frames.py' if necessary before extracting frames."
fi

echo ""
echo "--- Setup Script Finished ---"
echo "What to do next:"
echo "1. CRITICAL: Ensure 'numpy', 'opencv-python', and 'pyparsing' are NOT in 'requirements.txt'."
echo "2. If not already done, add your MP4 video to the project."
echo "3. Ensure 'src/extract_frames.py' points to your video file."
echo "4. The venv ('$VENV_DIR') should be active. If you open a new shell, re-enter nix-shell then 'source $VENV_DIR/bin/activate'."
echo "5. Extract frames: python3 src/extract_frames.py"
echo "6. Compile and run your project using the scripts in '$BASH_SCRIPTS_DIR/'."
echo ""