#include "task_queue.h"
#include <dirent.h>
#include <string.h>
#include <stdio.h>

void init_task_queue(TaskQueue* queue) {
    queue->total_tasks = 0;
    queue->current_index = 0;

    // First read all filenames
    DIR* dir = opendir("frames/");
    struct dirent* entry;

    while ((entry = readdir(dir)) != NULL) {
        if (strstr(entry->d_name, ".jpg")) {
            snprintf(
                queue->filenames[queue->total_tasks],
                MAX_FILENAME_LEN,
                "frames/%.200s", // truncate long names
                entry->d_name
            );
            queue->total_tasks++;
            if (queue->total_tasks >= MAX_TASKS) break;
        }
    }

    closedir(dir);

    // Sort frames numerically (assuming format frame_XXXX.jpg)
    qsort(queue->filenames, queue->total_tasks, MAX_FILENAME_LEN, 
        (int (*)(const void*, const void*))strcmp);
}

const char* get_next_task(TaskQueue* queue) {
    if (queue->current_index >= queue->total_tasks) return NULL;
    return queue->filenames[queue->current_index++];
}