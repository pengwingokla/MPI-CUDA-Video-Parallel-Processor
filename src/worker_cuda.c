#include <mpi.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>  // Added for usleep
#include "frame_io.h"
#include "cuda_filter.h"
#include "utils.h"

#define TAG_TASK_REQUEST 1
#define TAG_TASK_SEND    2
#define TAG_RESULT       3
#define TAG_TERMINATE    4
#define MAX_FILENAME_LEN 256
#define EDGE_TAG 99

void run_worker_cuda(int rank, int world_size) {
    int termination_received = 0;
    int dummy = 0;
    double worker_start_time = MPI_Wtime();
    int current_frame_num = -1;
    unsigned char* prev_edge = NULL;
    int prev_width = 0, prev_height = 0;

    while (!termination_received) {
        // Debug: Worker 2 timeout check
        if (rank == 2 && (MPI_Wtime() - worker_start_time > 10.0)) {
            log_error("WORKER %d EMERGENCY: No termination after 10 seconds!", rank);
            log_error("  Current state: termination_received=%d, last_frame=%d", 
                     termination_received, current_frame_num);
            
            if (rank < world_size - 1) {
                unsigned char emergency_signal = 0xFF;
                MPI_Send(&emergency_signal, 1, MPI_UNSIGNED_CHAR, rank+1, EDGE_TAG, MPI_COMM_WORLD);
                log_info("WORKER %d: Sent emergency signal to %d", rank, rank+1);
            }
            // Graceful fallback: send TERMINATE ack to master
            MPI_Send(&dummy, 1, MPI_INT, 0, TAG_TERMINATE, MPI_COMM_WORLD);
            log_info("WORKER %d: Sent emergency TERMINATE ack to master", rank);

            break;
        }

        // Request task
        MPI_Send(&dummy, 1, MPI_INT, 0, TAG_TASK_REQUEST, MPI_COMM_WORLD);
        log_info("WORKER %d: Requested new task (last frame: %d)", rank, current_frame_num);

        // Receive task
        MPI_Status status;
        char task[MAX_FILENAME_LEN];
        MPI_Recv(task, MAX_FILENAME_LEN, MPI_CHAR, 0, MPI_ANY_TAG, MPI_COMM_WORLD, &status);

        if (status.MPI_TAG == TAG_TERMINATE) {
            log_info("WORKER %d: Received TERMINATE signal", rank);
            termination_received = 1;
            
            // Final edge transfer for cleanup
            if (rank < world_size - 1) {
                unsigned char dummy_edge = 0;
                MPI_Send(&dummy_edge, 1, MPI_UNSIGNED_CHAR, rank+1, EDGE_TAG, MPI_COMM_WORLD);
                log_info("WORKER %d: Sent final edge signal to %d", rank, rank+1);
            }
            
            MPI_Send(&dummy, 1, MPI_INT, 0, TAG_TERMINATE, MPI_COMM_WORLD);
            log_info("WORKER %d: Termination complete", rank);
            break;
        }

        // Extract frame number
        int frame_num;
        if (sscanf(task, "frames/frame_%d.jpg", &frame_num) != 1) {
            log_error("WORKER %d: Failed to parse frame number from %s", rank, task);
            continue;
        }
        log_info("WORKER %d: Processing frame %d", rank, frame_num);

        // Get previous frame's edges (if not first frame)
        if (frame_num > 0) {
            int expected_prev = frame_num - 1;
            if (prev_edge == NULL || expected_prev != current_frame_num) {
                int edge_dims[2] = {0, 0};
                int retries = 0;
                const int max_retries = 200;  // Retry for up to 2 seconds
        
                while (edge_dims[0] == 0 || edge_dims[1] == 0) {
                    log_info("WORKER %d: Requesting edges for frame %d (attempt %d)", rank, expected_prev, retries + 1);
                    MPI_Send(&expected_prev, 1, MPI_INT, 0, TAG_EDGE_REQUEST, MPI_COMM_WORLD);
                    MPI_Recv(edge_dims, 2, MPI_INT, 0, TAG_EDGE_DIMS, MPI_COMM_WORLD, &status);
        
                    if (edge_dims[0] == 0 || edge_dims[1] == 0) {
                        retries++;
                        if (retries >= max_retries) {
                            log_error("WORKER %d: Timeout waiting for edges of frame %d — skipping temporal linking.", rank, expected_prev);
                            break;
                        }
                        usleep(10000);  // wait 10ms
                    }
                }
        
                // Only receive edge data if dimensions are valid
                if (edge_dims[0] > 0 && edge_dims[1] > 0) {
                    if (prev_edge) free(prev_edge);
                    prev_width = edge_dims[0];
                    prev_height = edge_dims[1];
                    prev_edge = malloc(prev_width * prev_height);
        
                    MPI_Recv(prev_edge, prev_width * prev_height, MPI_UNSIGNED_CHAR,
                             0, TAG_EDGE_DATA, MPI_COMM_WORLD, &status);
        
                    log_info("WORKER %d: Received edges for frame %d (%dx%d)",
                             rank, expected_prev, prev_width, prev_height);
                } else {
                    if (prev_edge) {
                        free(prev_edge);
                        prev_edge = NULL;
                    }
                    prev_width = prev_height = 0;
                }
            }
        }
        
        

        // Process frame with temporal linking
        int w, h, c;
        unsigned char* img = load_image(task, &w, &h, &c);
        if (!img) {
            log_error("WORKER %d: Failed to load image: %s", rank, task);
            continue;
        }

        unsigned char* output_img = malloc(w * h);
        unsigned char* output_edges = malloc(w * h);
        
        cuda_canny(img, output_edges, w, h, c, prev_edge);
        log_info("WORKER %d: Processed frame %d with temporal linking", rank, frame_num);

        // Save results
        char output_filename[MAX_FILENAME_LEN];
        snprintf(output_filename, sizeof(output_filename), "output/output_mpi_cuda/frame_%04d.jpg", frame_num);
        save_image(output_filename, output_edges, w, h, 1);
        log_info("WORKER %d: Saved %s", rank, output_filename);

        // Send edges back to master for other workers
        int dims[2] = {w, h};
        MPI_Send(dims, 2, MPI_INT, 0, TAG_EDGE_DIMS, MPI_COMM_WORLD);
        MPI_Send(task, MAX_FILENAME_LEN, MPI_CHAR, 0, TAG_EDGE_DIMS, MPI_COMM_WORLD);
        MPI_Send(output_edges, w * h, MPI_UNSIGNED_CHAR, 0, TAG_EDGE_DATA, MPI_COMM_WORLD);
        log_info("WORKER %d: Sent edges for frame %d to master", rank, frame_num);

        // Update state
        current_frame_num = frame_num;
        free(img);
        free(output_img);
    }
    
    if (prev_edge) free(prev_edge);
}