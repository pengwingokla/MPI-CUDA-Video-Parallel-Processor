// include/utils.h
#ifndef UTILS_H
#define UTILS_H
#define TAG_TASK_REQUEST     1
#define TAG_TASK_SEND        2
#define TAG_RESULT           3
#define TAG_TERMINATE        4
#define TAG_EDGE_REQUEST     5
#define TAG_EDGE_DATA        6
#define TAG_EDGE_DIMS        7
#define MAX_FILENAME_LEN     256
#define EDGE_TAG             99

#include <stdio.h>
#include <stdarg.h>



// Simple logging utilities

static inline void log_info(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    fprintf(stdout, "[INFO] ");
    vfprintf(stdout, fmt, args);
    fprintf(stdout, "\n");
    va_end(args);
}

static inline void log_error(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    fprintf(stderr, "[ERROR] ");
    vfprintf(stderr, fmt, args);
    fprintf(stderr, "\n");
    va_end(args);
}

#endif // UTILS_H