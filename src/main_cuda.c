#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dirent.h> 
#include "frame_io.h"
#include "utils.h"
#include "cuda_filter.h"

#define MAX_FILENAME_LEN 256

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

int main() {
    int total_frames = count_frames("frames");
    if (total_frames == 0) {
        fprintf(stderr, "No frames found in 'frames/'\n");
        return 1;
    }

    char input_filename[MAX_FILENAME_LEN];
    char output_filename[MAX_FILENAME_LEN];

    double start_time = (double)clock() / CLOCKS_PER_SEC;

    for (int i = 0; i < total_frames; i++) {
        snprintf(input_filename, sizeof(input_filename), "frames/frame_%04d.jpg", i);

        int w, h, c;
        unsigned char* img = load_image(input_filename, &w, &h, &c);
        if (!img) {
            log_error("CUDA: Failed to load %s", input_filename);
            continue;
        }

        unsigned char* edges = malloc(w * h);
        cuda_canny(img, edges, w, h, c, NULL);  // No temporal linking for now

        snprintf(output_filename, sizeof(output_filename), "output/output_cuda/frame_%04d.jpg", i);
        save_image(output_filename, edges, w, h, 1);
        log_info("CUDA: Saved %s", output_filename);

        free(img);
        free(edges);
    }

    double end_time = (double)clock() / CLOCKS_PER_SEC;
    printf("CUDA-only processing took %.2f seconds\n", end_time - start_time);

    return 0;
}
