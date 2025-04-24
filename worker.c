#include <mpi.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "frame_io.h"

#define TAG_TASK_REQUEST 1
#define TAG_TASK_SEND    2
#define TAG_RESULT       3
#define TAG_TERMINATE    4
#define MAX_FILENAME_LEN 256

extern void cuda_sobel(unsigned char* input, unsigned char* output, int width, int height, int channels);

void run_worker(int rank) {
    while (1) {
        int dummy = 0;
        MPI_Send(&dummy, 1, MPI_INT, 0, TAG_TASK_REQUEST, MPI_COMM_WORLD);

        MPI_Status status;
        char task[MAX_FILENAME_LEN];
        MPI_Recv(task, MAX_FILENAME_LEN, MPI_CHAR, 0, MPI_ANY_TAG, MPI_COMM_WORLD, &status);

        if (status.MPI_TAG == TAG_TERMINATE) break;

        int w, h, c;
        unsigned char* img = load_image(task, &w, &h, &c);
        if (!img) {
            fprintf(stderr, "Worker %d: Failed to load %s\n", rank, task);
            continue;
        }

        unsigned char* output_img = malloc(w * h);
        cuda_sobel(img, output_img, w, h, c);

        char output_filename[256];
        const char* base = strrchr(task, '/');
        if (base) base++; else base = task;
        snprintf(output_filename, sizeof(output_filename), "output/%.240s", base);

        save_image(output_filename, output_img, w, h, 1);
        printf("Worker %d: Processed and saved %s\n", rank, output_filename);

        char result[512];
        snprintf(result, sizeof(result), "Worker %d classified %s", rank, task);
        MPI_Send(result, strlen(result) + 1, MPI_CHAR, 0, TAG_RESULT, MPI_COMM_WORLD);

        free(img);
        free(output_img);
    }
}
