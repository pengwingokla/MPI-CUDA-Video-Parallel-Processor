#include <mpi.h>
#include <stdio.h>
#include "utils.h"

void run_master(int world_size);
void run_worker(int rank);

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int rank, world_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    if (rank == 0)
        run_master(world_size);
    else
        run_worker(rank);

    MPI_Finalize();
    return 0;
}
