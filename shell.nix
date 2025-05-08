{ pkgs ? import <nixpkgs> {} }:

let
  pinnedPkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.11.tar.gz") {
    config.allowUnfree = true;
  };

  cuda = pinnedPkgs.cudaPackages_12;
in
pinnedPkgs.mkShell {
  name = "mpi-cuda-dev-env";

  buildInputs = with pinnedPkgs; [
    openmpi
    cuda.cudatoolkit
    cuda.cuda_nvcc
    gnumake
    gcc
    python3
    python3Packages.numpy
    opencv4
    imagemagick
  ];

  shellHook = ''
    export OMPI_CC=gcc
    export OMPI_CXX=g++
    export CUDA_PATH=${cuda.cudatoolkit}
    export PATH=$CUDA_PATH/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_PATH/lib64:${pinnedPkgs.openmpi}/lib:$LD_LIBRARY_PATH

    echo "✅ Environment ready with CUDA $(nvcc --version | grep release) and MPI $(mpirun --version | head -1)"
  '';
}
