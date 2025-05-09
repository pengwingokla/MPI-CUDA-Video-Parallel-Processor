{ pkgs ? import <nixpkgs> {} }:

let
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    numpy             # Add numpy explicitly
    opencv-python     # OpenCV bindings (provides cv2)
    pyparsing         # Add pyparsing
    # Add any other Python packages you want Nix to manage here
  ]);
in

pkgs.mkShell {
  name = "mpi-cuda-video-dev";

  buildInputs = [
    pkgs.gcc             # C/C++ compiler
    pkgs.gnumake         # GNU make
    pkgs.openmpi         # mpicc, mpicxx, mpirun
    pkgs.cudaPackages.cudatoolkit  # nvcc + CUDA runtime
    pkgs.ffmpeg          # FFmpeg CLI for video/frame encoding
    pythonEnv            # Python 3 interpreter with specified modules
  ];

  shellHook = ''
    echo "--- Nix Shell for MPI+CUDA Video Pipeline ---"
    echo "C Compiler: $(gcc --version | head -n1)"
    echo "MPI: $(mpicc --version | head -n1)"
    echo "CUDA: $(nvcc --version | grep "release")"
    echo "FFmpeg: $(ffmpeg -version | head -n1)"
    echo "Python3: $(python3 --version)"
    # This check in shellHook will now also reflect the added packages
    echo "  Checking for cv2: $(python3 -c "import cv2; print(cv2.__version__)" 2>/dev/null || echo 'Not found')"
    echo "  Checking for numpy: $(python3 -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo 'Not found')"
    echo "  Checking for pyparsing: $(python3 -c "import pyparsing; print(pyparsing.__version__)" 2>/dev/null || echo 'Not found')"
    echo ""
    echo "Now you can:"
    echo "  • (After Python venv setup) python3 src/extract_frames.py"
    echo "  • make -C src/v1_serial (Example - use root Makefile)"
    echo "  • Use scripts in bash_scripts/ to compile and run specific versions."
    echo ""
  '';
}