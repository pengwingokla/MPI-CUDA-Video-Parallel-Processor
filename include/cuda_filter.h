#ifndef CUDA_FILTER_H
#define CUDA_FILTER_H

#ifdef __cplusplus
extern "C" {
#endif

// -------------------- Host-callable APIs --------------------

// Main Canny edge detection
void cuda_canny(unsigned char* input, unsigned char* output,
    int width, int height, int channels,
    unsigned char* prev_edge);

// Grayscale threshold segmentation
void cuda_segment(unsigned char* input, unsigned char* output_mask, int w, int h, int c, unsigned char threshold);

// Connected Components
void cuda_connected_components(unsigned char* binary_input, int* host_labels, int width, int height);

// Segmentation + Labeling
void cuda_segment_and_label(unsigned char* input, int* output_labels, int width, int height, int channels, unsigned char threshold);

// Debug version: also returns intermediate mask
void cuda_segment_and_label_debug(unsigned char* input, int* output_labels,
    unsigned char* host_mask_out,
    int width, int height, int channels, unsigned char threshold);


// -------------------- Device Kernel Declarations --------------------
// __global__ void rgb_to_gray_kernel(unsigned char* input, unsigned char* gray, int width, int height, int channels);
// __global__ void segment_threshold_kernel(unsigned char* input, unsigned char* mask, int width, int height, int threshold);
// __global__ void cc_label_kernel(unsigned char* binary, int* labels, int width, int height);
// __global__ void cc_propagate_kernel(int* labels, int width, int height);

#ifdef __cplusplus
}
#endif

#endif // CUDA_FILTER_H
