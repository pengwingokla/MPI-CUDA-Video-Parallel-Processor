#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo ""
echo "--- MPI-CUDA Video Project Setup Script ---"

# --- Python Virtual Environment Setup ---
VENV_DIR="venv"

echo "[PYTHON] Ensuring a clean virtual environment '$VENV_DIR' with --system-site-packages..."
# Force removal of existing venv to ensure it's created fresh with current settings.
# This is important if the old venv was created without --system-site-packages
# or if Python version in Nix changed.
if [ -d "$VENV_DIR" ]; then
  echo "[PYTHON] Removing existing virtual environment '$VENV_DIR'..."
  rm -rf "$VENV_DIR"
fi

echo "[PYTHON] Creating Python virtual environment '$VENV_DIR' with --system-site-packages..."
# Using the python3 from the Nix shell.
# --system-site-packages allows the venv to access packages already installed
# in the Nix environment's Python (like numpy, opencv, pyparsing from shell.nix).
python3 -m venv "$VENV_DIR" --system-site-packages
echo "[PYTHON] Virtual environment created."


echo "[PYTHON] Activating virtual environment..."
source "$VENV_DIR/bin/activate"
echo "[PYTHON] Python interpreter in venv: $(which python3)"
echo "[PYTHON] Python version in venv: $(python3 --version)"

echo "[PYTHON] Checking access to Nix-provided packages within activated venv..."
# Give a moment for activation to fully settle in some environments, then check
sleep 1
echo "  cv2 version: $(python3 -c "import cv2; print(cv2.__version__)" 2>&1 || echo 'cv2: Not found or import error in venv')"
echo "  numpy version: $(python3 -c "import numpy; print(numpy.__version__)" 2>&1 || echo 'numpy: Not found or import error in venv')"
echo "  pyparsing version: $(python3 -c "import pyparsing; print(pyparsing.__version__)" 2>&1 || echo 'pyparsing: Not found or import error in venv')"


echo "[PYTHON] Upgrading pip in venv..."
pip install --upgrade pip

# Install requirements from requirements.txt if it exists
if [ -f "requirements.txt" ]; then
  echo "[PYTHON] Installing packages from requirements.txt..."
  echo "         Reminder: 'numpy', 'opencv-python', and 'pyparsing' should ideally be"
  echo "         REMOVED from requirements.txt to use the stable Nix-provided versions."
  pip install -r requirements.txt
else
  echo "[PYTHON] requirements.txt not found. Skipping 'pip install -r requirements.txt'."
fi

# Specifically for the 'latest' package, if not handled by requirements.txt
# pyparsing (its build dependency) should be available from system-site-packages.
if python3 -c "import latest" &> /dev/null; then
    echo "[PYTHON] 'latest' package is already installed or accessible."
else
    # Check if pyparsing is truly accessible before trying to install 'latest'
    if python3 -c "import pyparsing" &> /dev/null; then
        echo "[PYTHON] 'pyparsing' is accessible. Attempting to install 'latest' package..."
        pip install latest
        echo "[PYTHON] 'latest' package installation attempted."
    else
        echo "[PYTHON] ERROR: 'pyparsing' is NOT accessible in the venv. Cannot reliably build 'latest'."
        echo "         Please ensure 'pyparsing' is in 'pythonBasePackages' in your shell.nix and "
        echo "         that the venv was created correctly with --system-site-packages."
    fi
fi
echo "[PYTHON] Python environment setup complete."

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