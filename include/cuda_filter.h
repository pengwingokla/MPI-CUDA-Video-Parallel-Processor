#ifndef CUDA_FILTER_H
#define CUDA_FILTER_H

#ifdef __cplusplus
extern "C" {
#endif

// Main Canny interface
void cuda_canny(unsigned char* input, unsigned char* output,
    int width, int height, int channels,
    unsigned char* prev_edge);

void cuda_segment(unsigned char* input, unsigned char* output_mask, int w, int h, int c, unsigned char threshold);

#ifdef __cplusplus
}
#endif

#endif // CUDA_FILTER_H
