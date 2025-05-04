#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "frame_io.h"
#include "utils.h"
#include <time.h>

#define MAX_FILENAME_LEN 256

// Dummy CPU grayscale edge detection (for demo purposes)
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

int main() {
    clock_t start = clock();
    int total_frames = 3936;  // Adjust as needed
    char input_filename[MAX_FILENAME_LEN];
    char output_filename[MAX_FILENAME_LEN];

    for (int i = 0; i < total_frames; i++) {
        snprintf(input_filename, sizeof(input_filename), "frames/frame_%04d.jpg", i);
        int w, h, c;
        unsigned char* img = load_image(input_filename, &w, &h, &c);
        if (!img) {
            log_error("SERIAL: Failed to load %s", input_filename);
            continue;
        }

        unsigned char* edges = malloc(w * h);
        simple_edge_filter(img, edges, w, h, c);

        snprintf(output_filename, sizeof(output_filename), "output_serial/frame_%04d.jpg", i);
        save_image(output_filename, edges, w, h, 1);
        log_info("SERIAL: Saved %s", output_filename);

        free(img);
        free(edges);
    }

    clock_t end = clock();

    double elapsed = (double)(end - start) / CLOCKS_PER_SEC;
    printf("Serial processing took %.2f seconds\n", elapsed);

    return 0;
}
