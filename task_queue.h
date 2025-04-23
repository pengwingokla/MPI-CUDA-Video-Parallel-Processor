#ifndef TASK_QUEUE_H
#define TASK_QUEUE_H

#define MAX_TASKS 5000
#define MAX_FILENAME_LEN 256

typedef struct {
    char filenames[MAX_TASKS][MAX_FILENAME_LEN];
    int total_tasks;
    int current_index;
} TaskQueue;

void init_task_queue(TaskQueue* queue);
const char* get_next_task(TaskQueue* queue);

#endif
