#include <mpi.h>
#include <stdio.h>
#include <string.h>
#include "frame_io.h"

#define TAG_TASK_REQUEST 1
#define TAG_TASK_SEND    2
#define TAG_RESULT       3
#define TAG_TERMINATE    4
#define MAX_FILENAME_LEN 256

// External CUDA function
extern void cuda_invert(unsigned char* data, int w, int h, int c);

void run_worker(int rank) {
    while (1) {
        int dummy = 0;

        // Tell master: ready for task
        MPI_Send(&dummy, 1, MPI_INT, 0, TAG_TASK_REQUEST, MPI_COMM_WORLD);

        // Receive task (or terminate)
        MPI_Status status;
        char task[MAX_FILENAME_LEN];
        MPI_Recv(task, MAX_FILENAME_LEN, MPI_CHAR, 0, MPI_ANY_TAG, MPI_COMM_WORLD, &status);

        if (status.MPI_TAG == TAG_TERMINATE) {
            break;  // Exit loop if terminated
        }

        // Load image
        int w, h, c;
        unsigned char* img = load_image(task, &w, &h, &c);
        if (!img) {
            fprintf(stderr, "Worker %d: Failed to load %s\n", rank, task);
            continue;
        }

        // Process with CUDA
        cuda_invert(img, w, h, c);

        // Create output filename
        char output_filename[256];
        const char* base = strrchr(task, '/'); // get just the filename
        if (base) base++; else base = task;
        snprintf(output_filename, sizeof(output_filename), "output/%.240s", base);

        // Save processed image
        save_image(output_filename, img, w, h, c);
        printf("Worker %d: Processed and saved %s\n", rank, output_filename);

        // Send result back to master
        char result[512];
        snprintf(result, sizeof(result), "Worker %d classified %s", rank, task);
        MPI_Send(result, strlen(result) + 1, MPI_CHAR, 0, TAG_RESULT, MPI_COMM_WORLD);
    }
}
