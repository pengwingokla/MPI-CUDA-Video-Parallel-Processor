#include <mpi.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include "utils.h"
#include "task_queue.h"

#define TAG_TASK_REQUEST     1
#define TAG_TASK_SEND        2
#define TAG_RESULT           3
#define TAG_TERMINATE        4
#define TAG_EDGE_REQUEST     5
#define TAG_EDGE_DATA        6
#define TAG_EDGE_DIMS        7
#define MAX_FRAMES           10000  // Adjust based on your needs

typedef struct {
    unsigned char* edges;
    int width;
    int height;
    int available;
} FrameEdge;

void run_master(int world_size) {
    TaskQueue queue;
    init_task_queue(&queue);
    log_info("MASTER: Initialized queue with %d frames", queue.total_tasks);

    bool terminated[world_size];
    for (int i = 0; i < world_size; i++) terminated[i] = false;

    // Edge storage for temporal linking
    FrameEdge edge_storage[MAX_FRAMES] = {0};
    int tasks_sent = 0;
    int terminated_workers = 0;

    // Warm-up period
    for (int i = 0; i < 3; i++) {
        log_info("MASTER: Warm-up %d/3", i+1);
        sleep(1);
    }

    while (terminated_workers < world_size - 1) {
        MPI_Status status;
        int flag;
        MPI_Iprobe(MPI_ANY_SOURCE, MPI_ANY_TAG, MPI_COMM_WORLD, &flag, &status);

        if (flag) {
            // Handle edge data requests
            if (status.MPI_TAG == TAG_EDGE_REQUEST) {
                int requested_frame;
                MPI_Recv(&requested_frame, 1, MPI_INT, status.MPI_SOURCE, 
                        TAG_EDGE_REQUEST, MPI_COMM_WORLD, &status);
                
                log_info("MASTER: Worker %d requested edges for frame %d", 
                        status.MPI_SOURCE, requested_frame);

                if (requested_frame >= 0 && requested_frame < MAX_FRAMES && 
                    edge_storage[requested_frame].available) {
                    // Send edge dimensions first
                    int dims[2] = {edge_storage[requested_frame].width, 
                                  edge_storage[requested_frame].height};
                    MPI_Send(dims, 2, MPI_INT, status.MPI_SOURCE, 
                            TAG_EDGE_DIMS, MPI_COMM_WORLD);
                    
                    // Send edge data
                    MPI_Send(edge_storage[requested_frame].edges, 
                            dims[0] * dims[1], MPI_UNSIGNED_CHAR,
                            status.MPI_SOURCE, TAG_EDGE_DATA, MPI_COMM_WORLD);
                    
                    log_info("MASTER: Sent edges for frame %d to worker %d", 
                            requested_frame, status.MPI_SOURCE);
                } else {
                    log_error("MASTER: No edges available for frame %d", requested_frame);
                    int dims[2] = {0, 0};
                    MPI_Send(dims, 2, MPI_INT, status.MPI_SOURCE, 
                            TAG_EDGE_DIMS, MPI_COMM_WORLD);
                }
            }
            // Handle task requests
            else if (status.MPI_TAG == TAG_TASK_REQUEST) {
                int dummy;
                MPI_Recv(&dummy, 1, MPI_INT, status.MPI_SOURCE, TAG_TASK_REQUEST, MPI_COMM_WORLD, &status);
                int worker_rank = status.MPI_SOURCE;

                if (queue.current_index < queue.total_tasks) {
                    const char* task = get_next_task(&queue);
                    MPI_Send(task, MAX_FILENAME_LEN, MPI_CHAR, worker_rank, 
                            TAG_TASK_SEND, MPI_COMM_WORLD);
                    tasks_sent++;
                    log_info("MASTER: Sent frame %d/%d to worker %d", 
                        queue.current_index - 1, queue.total_tasks, worker_rank);
                } else {
                    if (!terminated[worker_rank]) {
                        MPI_Send(NULL, 0, MPI_CHAR, worker_rank, TAG_TERMINATE, MPI_COMM_WORLD);
                        terminated[worker_rank] = true;
                        terminated_workers++;
                        log_info("MASTER: Sent TERMINATE to worker %d (%d/%d terminated)", 
                                 worker_rank, terminated_workers, world_size - 1);
                    }
                }
            }
            // Handle edge data storage
            else if (status.MPI_TAG == TAG_EDGE_DIMS) {
                int dims[2];
                MPI_Recv(dims, 2, MPI_INT, status.MPI_SOURCE, 
                        TAG_EDGE_DIMS, MPI_COMM_WORLD, &status);
                
                int frame_num;
                char frame_path[MAX_FILENAME_LEN];
                MPI_Recv(frame_path, MAX_FILENAME_LEN, MPI_CHAR, status.MPI_SOURCE,
                    TAG_EDGE_DIMS, MPI_COMM_WORLD, &status);
                
                if (sscanf(frame_path, "frames/frame_%d.jpg", &frame_num) != 1) {
                    log_error("MASTER: Failed to parse frame number from '%s'", frame_path);
                    continue;
                }
                
                if (frame_num >= 0 && frame_num < MAX_FRAMES) {
                    // Free previous data if exists
                    if (edge_storage[frame_num].edges) {
                        free(edge_storage[frame_num].edges);
                    }
                    
                    edge_storage[frame_num].width = dims[0];
                    edge_storage[frame_num].height = dims[1];
                    edge_storage[frame_num].edges = malloc(dims[0] * dims[1]);
                    edge_storage[frame_num].available = 0;
                    
                    // Receive edge data
                    MPI_Recv(edge_storage[frame_num].edges, dims[0] * dims[1],
                            MPI_UNSIGNED_CHAR, status.MPI_SOURCE, TAG_EDGE_DATA,
                            MPI_COMM_WORLD, &status);
                    
                    edge_storage[frame_num].available = 1;
                    log_info("MASTER: Stored edges for frame %d (%dx%d)", 
                            frame_num, dims[0], dims[1]);
                }
            }
            // Handle termination acknowledgments
            else if (status.MPI_TAG == TAG_TERMINATE) {
                int ack;
                MPI_Recv(&ack, 1, MPI_INT, status.MPI_SOURCE, 
                        TAG_TERMINATE, MPI_COMM_WORLD, &status);
                log_info("MASTER: Received TERMINATE ack from worker %d", 
                        status.MPI_SOURCE);
                if (!terminated[status.MPI_SOURCE]) {
                    terminated[status.MPI_SOURCE] = true;
                    terminated_workers++;
                    log_info("MASTER: Now %d/%d workers terminated", terminated_workers, world_size - 1);
                }
            }
            // Handle results
            else if (status.MPI_TAG == TAG_RESULT) {
                char result[512];
                MPI_Recv(result, 512, MPI_CHAR, MPI_ANY_SOURCE, 
                        TAG_RESULT, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                log_info("MASTER: Received result: %s", result);
            }
        } else {
            usleep(1000); // Prevent busy waiting
        }
    }

    // Cleanup
    for (int i = 0; i < MAX_FRAMES; i++) {
        if (edge_storage[i].edges) {
            free(edge_storage[i].edges);
        }
    }
    
    log_info("MASTER: All workers terminated. Processed %d/%d frames.", 
            tasks_sent, queue.total_tasks);
}