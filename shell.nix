# shell.nix
{ pkgs ? import <nixpkgs> {} }:

let
  # Define Python packages to be included in the Nix environment's Python
  pythonBasePackages = ps: with ps; [
    opencv-python    # OpenCV bindings, includes numpy as a dependency
    pip              # To manage venv and further pip installs
    setuptools       # For building packages
    wheel            # For wheel support
    pyparsing        # Build dependency for the 'latest' package
  ];
  pythonEnv = pkgs.python3.withPackages pythonBasePackages;
in

pkgs.mkShell {
  name = "mpi-cuda-video-dev";

  buildInputs = [
    pkgs.gcc             # C/C++ compiler (provides libstdc++.so.6)
    pkgs.gnumake         # GNU make
    pkgs.openmpi         # mpicc, mpicxx, mpirun
    pkgs.cudaPackages.cudatoolkit  # nvcc + CUDA runtime
    pkgs.ffmpeg          # FFmpeg CLI for video/frame encoding
    pythonEnv            # Python 3 interpreter with cv2, numpy, pip, pyparsing
    pkgs.pkg-config      # Often useful for build systems finding libs
  ];

  shellHook = ''
    echo "--- Nix Shell for MPI+CUDA Video Pipeline ---"
    echo "Nix-provided tools:"
    echo "  C Compiler: $(gcc --version | head -n1)"
    echo "  MPI: $(mpicc --version | head -n1)"
    echo "  CUDA: $(nvcc --version | grep "release" || echo 'nvcc not found or version info changed')"
    echo "  FFmpeg: $(ffmpeg -version | head -n1 || echo 'ffmpeg not found')"
    echo "  Python3: $(python3 --version)"
    echo "    cv2 (from Nix): $(python3 -c "import cv2; print(cv2.__version__)" 2>/dev/null || echo 'Not found')"
    echo "    numpy (from Nix): $(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo 'Not found')"
    echo "    pyparsing (from Nix): $(python3 -c "import pyparsing; print(pyparsing.__version__)" 2>/dev/null || echo 'Not found')"
    echo ""
    echo "---------------------------------------------------------------------"
    echo "Automated Project Setup:"
    echo "If this is your first time or you've cleaned the project, run:"
    echo "  ./project_setup.sh"
    echo "This script will create/configure the Python virtual environment ('venv'),"
    echo "install dependencies, and set up directories."
    echo "---------------------------------------------------------------------"
    echo ""
    echo "Once setup is complete (or if already done):"
    echo "  1. Ensure your video file is in the project root or 'frames/' directory."
    echo "  2. Activate venv: source venv/bin/activate"
    echo "  3. Extract frames: python3 src/extract_frames.py"
    echo "  4. Run your compiled programs: ./bash_scripts/vX_xxx.sh"
    echo ""
    echo "If you encounter issues with NumPy/OpenCV *after* running project_setup.sh:"
    echo "  - Ensure 'numpy' and 'opencv-python' are NOT in your 'requirements.txt',"
    echo "    as this shell provides them (accessible in venv via --system-site-packages)."
    echo "  - If they MUST be in 'requirements.txt' (e.g., for a different version),"
    echo "    the project_setup.sh script offers advice on how to potentially rebuild them from source."
    echo "---"

    # Automatically add the project_setup.sh script to PATH if it exists and is executable
    # So user can just type 'project_setup.sh'
    # Or, we can just instruct them to run ./project_setup.sh
    # For now, relying on instructions.
  '';
}