#include <mpi.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "task_queue.h"

#define TAG_TASK_REQUEST 1
#define TAG_TASK_SEND    2
#define TAG_RESULT       3
#define TAG_TERMINATE    4

void run_master(int world_size) {
    TaskQueue queue;
    init_task_queue(&queue);

    int tasks_sent = 0;
    int active_workers = world_size - 1;

    printf("Master: I am alive with %d total processes.\n", world_size);

    // You can simulate some work or just wait a bit
    for (int i = 0; i < 5; ++i) {
        printf("Master: waiting... (%d)\n", i);
        sleep(1);
    }


    while (active_workers > 0) {
        MPI_Status status;
        int dummy;

        // Wait for task request
        MPI_Recv(&dummy, 1, MPI_INT, MPI_ANY_SOURCE, TAG_TASK_REQUEST, MPI_COMM_WORLD, &status);
        int worker_rank = status.MPI_SOURCE;

        const char* task = get_next_task(&queue);
        if (task) {
            MPI_Send(task, MAX_FILENAME_LEN, MPI_CHAR, worker_rank, TAG_TASK_SEND, MPI_COMM_WORLD);
            tasks_sent++;
        } else {
            MPI_Send(NULL, 0, MPI_CHAR, worker_rank, TAG_TERMINATE, MPI_COMM_WORLD);
            active_workers--;
        }
    }
    

    // Receive all results
    for (int i = 0; i < tasks_sent; ++i) {
        char result[512];
        MPI_Recv(result, 512, MPI_CHAR, MPI_ANY_SOURCE, TAG_RESULT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        printf("Received result: %s\n", result);
    }

    
    printf("Master: finished.\n");
}
