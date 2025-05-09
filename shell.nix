{ pkgs ? import <nixpkgs> {} }:

let
  # A Python 3 environment with opencv-python available as `import cv2`
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    ps.opencv-python    # OpenCV bindings for Python :contentReference[oaicite:6]{index=6}
  ]);
in

pkgs.mkShell {
  name = "mpi-cuda-video-dev";

  buildInputs = [
    pkgs.gcc             # C/C++ compiler
    pkgs.gnumake         # GNU make
    pkgs.openmpi         # mpicc, mpicxx, mpirun :contentReference[oaicite:7]{index=7}
    pkgs.cudaPackages.cudatoolkit  # nvcc + CUDA runtime
    pkgs.ffmpeg          # FFmpeg CLI for video/frame encoding :contentReference[oaicite:8]{index=8}
    pythonEnv            # Python 3 interpreter with cv2 module
  ];

  shellHook = ''
    echo "--- Nix Shell for MPI+CUDA Video Pipeline ---"
    echo "C Compiler: $(gcc --version | head -n1)"
    echo "MPI: $(mpicc --version | head -n1)"
    echo "CUDA: $(nvcc --version | grep "release")"
    echo "FFmpeg: $(ffmpeg -version | head -n1)"
    echo "Python3: $(python3 --version)"
    echo "  Modules: cv2 -> $(python3 -c "import cv2; print(cv2.__version__)")"
    echo ""
    echo "Now you can:"
    echo "  • make -C src/v1_serial"
    echo "  • mpirun -np 4 make -C src/v2_mpi_only/…/template"
    echo "  • make -C src/v3_cuda_only && ./src/v3_cuda_only/template"
    echo "  • mpirun -np 8 make -C src/v4_mpi_cuda && ./src/v4_mpi_cuda/template"
    echo ""
  '';
}
