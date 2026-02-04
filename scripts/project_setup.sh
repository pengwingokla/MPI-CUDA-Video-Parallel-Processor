#!/usr/bin/env bash

set -e # Exit immediately if a command exits with a non-zero status.

echo ""
echo "--- MPI-CUDA Video Project Setup Script (Diagnostic Version) ---"

VENV_DIR="venv"

echo "[PYTHON] Ensuring a clean virtual environment '$VENV_DIR' with --system-site-packages..."
if [ -d "$VENV_DIR" ]; then
  echo "[PYTHON] Removing existing virtual environment '$VENV_DIR'..."
  rm -rf "$VENV_DIR"
fi

echo "[PYTHON] Identifying Nix Python interpreter..."
NIX_PYTHON_PATH=$(which python3)
if [ -z "$NIX_PYTHON_PATH" ]; then
    echo "[ERROR] Could not determine Nix Python path. Exiting."
    exit 1
fi
echo "[PYTHON] Nix Python is: $NIX_PYTHON_PATH"
echo "[PYTHON] Nix Python version: $($NIX_PYTHON_PATH --version)"

echo "[PYTHON] Creating Python virtual environment '$VENV_DIR' using '$NIX_PYTHON_PATH' with --system-site-packages..."
"$NIX_PYTHON_PATH" -m venv "$VENV_DIR" --system-site-packages
echo "[PYTHON] Virtual environment created."

echo "[PYTHON] Checking '$VENV_DIR/pyvenv.cfg'..."
if [ -f "$VENV_DIR/pyvenv.cfg" ]; then
    cat "$VENV_DIR/pyvenv.cfg"
    if grep -q "include-system-site-packages = true" "$VENV_DIR/pyvenv.cfg"; then
        echo "[PYTHON] '$VENV_DIR/pyvenv.cfg' includes system site packages."
    else
        echo "[PYTHON] WARNING: '$VENV_DIR/pyvenv.cfg' DOES NOT specify include-system-site-packages = true. This is a problem!"
    fi
else
    echo "[PYTHON] WARNING: '$VENV_DIR/pyvenv.cfg' not found!"
fi

echo "[PYTHON] Activating virtual environment..."
source "$VENV_DIR/bin/activate"
echo "[PYTHON] Python interpreter in venv: $(which python3)"
echo "[PYTHON] Python version in venv: $(python3 --version)"

echo "[PYTHON] Displaying sys.path from within activated venv..."
python3 -c "import sys; import pprint; pprint.pprint(sys.path)"

echo "[PYTHON] Checking access to Nix-provided packages within activated venv..."
sleep 1 # Give a moment for activation
echo "  Attempting to import cv2..."
python3 -c "import cv2; print(f'cv2 version: {cv2.__version__}')" || echo "  cv2: Import failed."
echo "  Attempting to import numpy..."
python3 -c "import numpy; print(f'numpy version: {numpy.__version__}')" || echo "  numpy: Import failed."
echo "  Attempting to import pyparsing..."
python3 -c "import pyparsing; print(f'pyparsing version: {pyparsing.__version__}')" || echo "  pyparsing: Import failed."


echo "[PYTHON] Upgrading pip in venv..."
pip install --upgrade pip

if [ -f "requirements.txt" ]; then
  echo "[PYTHON] Installing packages from requirements.txt..."
  echo "         Reminder: 'numpy', 'opencv-python', and 'pyparsing' should ideally be"
  echo "         REMOVED from requirements.txt to use the stable Nix-provided versions."
  pip install -r requirements.txt
else
  echo "[PYTHON] requirements.txt not found. Skipping 'pip install -r requirements.txt'."
fi

if python3 -c "import sys; sys.exit(0 if 'pyparsing' in sys.modules else 1)" || python3 -c "import pyparsing" &> /dev/null; then
    echo "[PYTHON] 'pyparsing' is accessible. Attempting to install 'latest' package..."
    pip install latest
    echo "[PYTHON] 'latest' package installation attempted."
else
    echo "[PYTHON] WARNING: 'pyparsing' is NOT accessible in the venv after potential requirements install. Cannot reliably build 'latest'."
fi
echo "[PYTHON] Python environment setup complete."

FRAMES_DIR="frames"
OUTPUT_DIR="output"
SCRIPTS_DIR="scripts"
echo "[PROJECT] Ensuring directory structure..."
mkdir -p "$FRAMES_DIR" "$OUTPUT_DIR" "data/videos" "data/output" "bin" "config"
echo "[PROJECT] '$FRAMES_DIR', '$OUTPUT_DIR', 'data/videos', 'data/output', 'bin', and 'config' directories ensured."

if [ -d "$SCRIPTS_DIR" ]; then
  echo "[PROJECT] Making bash scripts in '$SCRIPTS_DIR/' executable..."
  chmod +x "$SCRIPTS_DIR"/*.sh
  echo "[PROJECT] Bash scripts are now executable."
else
  echo "[WARN] '$SCRIPTS_DIR' directory not found."
fi

VIDEO_FILE_CANDIDATE=$(find data/videos -maxdepth 1 -iname "*.mp4" -print -quit 2>/dev/null)
if [ -n "$VIDEO_FILE_CANDIDATE" ]; then
    echo "[PROJECT] Found a video file: '$VIDEO_FILE_CANDIDATE'."
else
    echo "[WARN] No .mp4 video found in project root."
fi

echo ""
echo "--- Setup Script Finished ---"
echo "Review the diagnostic output above, especially sys.path and import attempts."
echo "Next steps:"
echo "1. CRITICAL: Ensure 'numpy', 'opencv-python', 'pyparsing' are NOT in 'requirements.txt'."
echo "2. Add your MP4 video if needed."
echo "3. The venv should be active. If not: source $VENV_DIR/bin/activate"
echo "4. Try: python3 src/extract_frames.py"