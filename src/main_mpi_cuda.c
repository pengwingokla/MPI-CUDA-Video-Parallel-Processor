#include <mpi.h>
#include <stdio.h>
#include "utils.h"

void run_master(int world_size);
void run_worker_cuda(int rank);

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int rank, world_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    log_info("MPI initialized with %d processes.", world_size);

    double start_time = MPI_Wtime();

    if (rank == 0) {
        run_master(world_size);
    } else {
        run_worker_cuda(rank);
    }

    double end_time = MPI_Wtime();
    if (rank == 0) {
        log_info("Total MPI+CUDA execution time: %.2f seconds", end_time - start_time);
    }

    MPI_Finalize();
    return 0;
}
