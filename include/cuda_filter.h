#ifndef CUDA_FILTER_H
#define CUDA_FILTER_H

#ifdef __cplusplus
extern "C" {
#endif

// Main Canny interface
void cuda_canny(unsigned char* input, unsigned char* output, int width, int height, int channels);

#ifdef __cplusplus
}
#endif

#endif // CUDA_FILTER_H
