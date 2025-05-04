#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "frame_io.h"
#include "cuda_filter.h"

int main() {
    int w, h, c;
    const char* test_img = "frames/frame_0000.jpg";

    unsigned char* img = load_image(test_img, &w, &h, &c);
    if (!img) {
        fprintf(stderr, "Failed to load image: %s\n", test_img);
        return 1;
    }

    unsigned char* mask = (unsigned char*)malloc(w * h);

    // Run segmentation
    cuda_segment(img, mask, w, h, c, 100);  // Simple grayscale threshold

    // Save result
    save_image("test_segment_output.jpg", mask, w, h, 1);
    printf("Segmentation mask saved to test_segment_output.jpg\n");

    free(img);
    free(mask);
    return 0;
}
