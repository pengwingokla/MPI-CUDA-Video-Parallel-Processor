#ifndef CUDA_SEGMENTATION_H
#define CUDA_SEGMENTATION_H

#ifdef __cplusplus
extern "C" {
#endif

void cuda_segment_and_label(
    unsigned char* input, int* output_labels,
    int width, int height, int channels, unsigned char threshold
);

#ifdef __cplusplus
}
#endif

#endif  // CUDA_SEGMENTATION_H
