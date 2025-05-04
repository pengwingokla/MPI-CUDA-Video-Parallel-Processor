#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "frame_io.h"
#include "utils.h"
#include <dirent.h>


#define MAX_FILENAME_LEN 256
#define TAG_TASK 1

// CPU-only filtering
void simple_edge_filter(unsigned char* input, unsigned char* output, int w, int h, int c) {
    for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
            int gx = input[(y * w + (x+1)) * c] - input[(y * w + (x-1)) * c];
            int gy = input[((y+1) * w + x) * c] - input[((y-1) * w + x) * c];
            int mag = abs(gx) + abs(gy);
            output[y * w + x] = (mag > 100) ? 255 : 0;
        }
    }
}

// Count frame
int count_frames(const char* folder) {
    int count = 0;
    DIR* dir = opendir(folder);
    if (!dir) {
        perror("Failed to open frames directory");
        return 0;
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strstr(entry->d_name, "frame_") && strstr(entry->d_name, ".jpg"))
            count++;
    }

    closedir(dir);
    return count;
}

void master(int total_frames, int world_size) {
    int frame_index = 0;
    int active_workers = world_size - 1;

    for (int rank = 1; rank < world_size && frame_index < total_frames; ++rank) {
        MPI_Send(&frame_index, 1, MPI_INT, rank, TAG_TASK, MPI_COMM_WORLD);
        frame_index++;
    }

    while (active_workers > 0) {
        int worker_rank, frame_done;
        MPI_Status status;
        MPI_Recv(&frame_done, 1, MPI_INT, MPI_ANY_SOURCE, MPI_ANY_TAG, MPI_COMM_WORLD, &status);
        worker_rank = status.MPI_SOURCE;

        if (frame_index < total_frames) {
            MPI_Send(&frame_index, 1, MPI_INT, worker_rank, TAG_TASK, MPI_COMM_WORLD);
            frame_index++;
        } else {
            int dummy = -1;
            MPI_Send(&dummy, 1, MPI_INT, worker_rank, TAG_TERMINATE, MPI_COMM_WORLD);
            active_workers--;
        }
    }
}

void worker(int rank) {
    int w, h, c;
    int frame_num;
    char input_filename[MAX_FILENAME_LEN];
    char output_filename[MAX_FILENAME_LEN];

    while (1) {
        MPI_Status status;
        MPI_Recv(&frame_num, 1, MPI_INT, 0, MPI_ANY_TAG, MPI_COMM_WORLD, &status);

        if (status.MPI_TAG == TAG_TERMINATE) {
            break;
        }

        snprintf(input_filename, sizeof(input_filename), "frames/frame_%04d.jpg", frame_num);
        unsigned char* img = load_image(input_filename, &w, &h, &c);
        if (!img) {
            log_error("WORKER %d: Failed to load frame %s", rank, input_filename);
            MPI_Send(&frame_num, 1, MPI_INT, 0, 0, MPI_COMM_WORLD);
            continue;
        }

        unsigned char* edges = malloc(w * h);
        simple_edge_filter(img, edges, w, h, c);

        snprintf(output_filename, sizeof(output_filename), "output_mpi/frame_%04d.jpg", frame_num);
        save_image(output_filename, edges, w, h, 1);
        log_info("WORKER %d: Saved %s", rank, output_filename);

        free(img);
        free(edges);

        MPI_Send(&frame_num, 1, MPI_INT, 0, 0, MPI_COMM_WORLD);
    }
}

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);
    int rank, world_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    int total_frames = count_frames("frames");

    double start_time = 0.0;
    if (rank == 0) {
        log_info("MASTER: Starting with %d frames and %d workers", total_frames, world_size - 1);
        start_time = MPI_Wtime();
    }

    if (rank == 0) {
        master(total_frames, world_size);
        double end_time = MPI_Wtime();
        log_info("MASTER: All frames processed.");
        printf("Total MPI execution time: %.2f seconds\n", end_time - start_time);
    } else {
        worker(rank);
    }

    MPI_Finalize();
    return 0;
}

