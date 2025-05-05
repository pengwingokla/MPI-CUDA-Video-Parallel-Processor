#include <cuda_runtime.h>
#include <math.h>
#include "cuda_filter.h"

// Convert RGB image to grayscale
__global__ void rgb_to_gray_kernel(unsigned char* input, unsigned char* gray, int width, int height, int channels) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= width * height) return;
    int i = idx * channels;
    gray[idx] = 0.299f * input[i] + 0.587f * input[i+1] + 0.114f * input[i+2];
}

// Apply Gaussian Blur
__global__ void gaussian_blur_kernel_3x3(unsigned char* gray, unsigned char* blurred, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) return;

    int sum = 0;
    int i = y * width + x;
    int weights[3][3] = {{1, 2, 1}, {2, 4, 2}, {1, 2, 1}};
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            int px = x + dx;
            int py = y + dy;
            sum += gray[py * width + px] * weights[dy + 1][dx + 1];
        }
    }
    blurred[i] = sum / 16;
}

// Example 5x5 Gaussian (approx. σ = 1.4, normalized)
__constant__ int gauss5x5[5][5] = {
    {1,  4,  6,  4, 1},
    {4, 16, 24, 16, 4},
    {6, 24, 36, 24, 6},
    {4, 16, 24, 16, 4},
    {1,  4,  6,  4, 1}
};

__global__ void gaussian_blur_kernel_5x5(unsigned char* gray, unsigned char* blurred, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x < 2 || y < 2 || x >= width - 2 || y >= height - 2) return;

    int sum = 0;
    int weight_sum = 256;
    int i = y * width + x;

    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            int px = x + dx;
            int py = y + dy;
            sum += gray[py * width + px] * gauss5x5[dy + 2][dx + 2];
        }
    }
    blurred[i] = sum / weight_sum;
}

// Apply Sobel filter
__global__ void sobel_kernel(unsigned char* blurred, unsigned char* edge, float* direction, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) return;

    int i = y * width + x;
    int Gx = -1 * blurred[(y-1)*width + (x-1)] + 1 * blurred[(y-1)*width + (x+1)]
           -2 * blurred[y*width + (x-1)] + 2 * blurred[y*width + (x+1)]
           -1 * blurred[(y+1)*width + (x-1)] + 1 * blurred[(y+1)*width + (x+1)];

    int Gy = -1 * blurred[(y-1)*width + (x-1)] - 2 * blurred[(y-1)*width + x] - 1 * blurred[(y-1)*width + (x+1)]
           +1 * blurred[(y+1)*width + (x-1)] + 2 * blurred[(y+1)*width + x] + 1 * blurred[(y+1)*width + (x+1)];

    edge[i] = min(255, (int)sqrtf((float)(Gx * Gx + Gy * Gy)));

    float angle = atan2f((float)Gy, (float)Gx) * 180.0f / M_PI;
    direction[i] = angle;

}

// Apply non-maximum suppression
__global__ void non_max_suppression_kernel(unsigned char* gradient, float* direction, unsigned char* output, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) return;

    int i = y * width + x;
    float angle = direction[i];
    float mag = gradient[i];
    

    float m1 = 0, m2 = 0;

    // Angle normalization: 0°, 45°, 90°, 135°
    angle = fmodf(angle + 180.0f, 180.0f);  // Normalize to [0,180)

    if ((angle >= 0 && angle < 22.5) || (angle >= 157.5 && angle < 180)) {
        m1 = gradient[i + 1];
        m2 = gradient[i - 1];
    } else if (angle >= 22.5 && angle < 67.5) {
        m1 = gradient[(y - 1) * width + (x + 1)];
        m2 = gradient[(y + 1) * width + (x - 1)];
    } else if (angle >= 67.5 && angle < 112.5) {
        m1 = gradient[(y - 1) * width + x];
        m2 = gradient[(y + 1) * width + x];
    } else if (angle >= 112.5 && angle < 157.5) {
        m1 = gradient[(y - 1) * width + (x - 1)];
        m2 = gradient[(y + 1) * width + (x + 1)];
    }

    if (mag >= m1 && mag >= m2) {
        output[i] = (unsigned char)mag;
    } else {
        output[i] = 0;
    }
}

// Apply double thresholding
__global__ void double_threshold_kernel(unsigned char* input, unsigned char* output, int width, int height, unsigned char low_thresh, unsigned char high_thresh) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= width * height) return;

    unsigned char val = input[idx];
    if (val >= high_thresh) {
        output[idx] = 255;  // Strong edge
    } else if (val >= low_thresh) {
        output[idx] = 100;  // Weak edge
    } else {
        output[idx] = 0;    // Non-edge
    }
}

// Suppress isolated weak edges
__global__ void suppress_weak_clusters_kernel(unsigned char* input, unsigned char* output, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) return;

    int i = y * width + x;
    if (input[i] == 100) { // weak edge
        int count = 0;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                int ni = (y + dy) * width + (x + dx);
                if (input[ni] == 100 || input[ni] == 255) count++;
            }
        }
        output[i] = (count >= 5) ? 100 : 0;
    } else {
        output[i] = input[i];
    }
}

// DFS-based edge tracking kernel (one pass propagation)
__global__ void edge_tracking_dfs_kernel(unsigned char* input, unsigned char* output, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) return;

    int i = y * width + x;
    if (input[i] == 255) {
        output[i] = 255;
        return;
    }

    if (input[i] == 100) {
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                int nx = x + dx;
                int ny = y + dy;
                int ni = ny * width + nx;
                if (input[ni] == 255) {
                    output[i] = 255;
                    return;
                }
            }
        }
        output[i] = 0;
    } else {
        output[i] = 0;
    }
}

// Temporal Linking Kernel
__global__ void temporal_link_kernel(unsigned char* curr_edge, unsigned char* prev_edge, unsigned char* output, int width, int height) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= width * height) return;

    if (curr_edge[idx] && prev_edge[idx])
        output[idx] = 255;  // Reinforce edge
    else
        output[idx] = 0;    // Suppress unstable edge
}

extern "C"
void cuda_canny(unsigned char* input, unsigned char* output, int width, int height, int channels, unsigned char* prev_edge) {
    int img_size = width * height;
    unsigned char *d_input, *d_gray, *d_blur, *d_edge, *d_nms, *d_thresh, *d_final, *d_cleaned, *d_prev_edge, *d_temporal;
    float* d_direction;

    cudaMalloc(&d_input, img_size * channels);
    cudaMalloc(&d_gray, img_size);
    cudaMalloc(&d_blur, img_size);
    cudaMalloc(&d_edge, img_size);
    cudaMalloc(&d_nms, img_size);
    cudaMalloc(&d_thresh, img_size);
    cudaMalloc(&d_final, img_size);
    cudaMalloc(&d_cleaned, img_size);
    cudaMalloc(&d_prev_edge, img_size);
    cudaMalloc(&d_temporal, img_size);
    cudaMalloc(&d_direction, img_size * sizeof(float));

    cudaMemcpy(d_input, input, img_size * channels, cudaMemcpyHostToDevice);

    int threads = 256;
    int blocks = (img_size + threads - 1) / threads;
    rgb_to_gray_kernel<<<blocks, threads>>>(d_input, d_gray, width, height, channels);

    dim3 threadsPerBlock(16, 16);
    dim3 numBlocks((width + 15) / 16, (height + 15) / 16);
    gaussian_blur_kernel_5x5<<<numBlocks, threadsPerBlock>>>(d_gray, d_blur, width, height);
    sobel_kernel<<<numBlocks, threadsPerBlock>>>(d_blur, d_edge, d_direction, width, height);
    non_max_suppression_kernel<<<numBlocks, threadsPerBlock>>>(d_edge, d_direction, d_nms, width, height);

    // Apply double thresholding: low = 50, high = 100
    double_threshold_kernel<<<blocks, threads>>>(d_nms, d_thresh, width, height, 50, 100);

    // Suppress weak clusters
    suppress_weak_clusters_kernel<<<numBlocks, threadsPerBlock>>>(d_thresh, d_cleaned, width, height);
    
    // Temporal link kernel
    temporal_link_kernel<<<blocks, threads>>>(d_thresh, d_prev_edge, d_temporal, width, height);

    // Run edge tracking 2 iterations
    edge_tracking_dfs_kernel<<<numBlocks, threadsPerBlock>>>(d_thresh, d_final, width, height);
    edge_tracking_dfs_kernel<<<numBlocks, threadsPerBlock>>>(d_final, d_thresh, width, height);

    cudaMemcpy(output, d_thresh, img_size, cudaMemcpyDeviceToHost);

    cudaFree(d_input);
    cudaFree(d_gray);
    cudaFree(d_blur);
    cudaFree(d_edge);
    cudaFree(d_nms);
    cudaFree(d_thresh);
    cudaFree(d_final);
    cudaFree(d_cleaned);
    cudaFree(d_direction);
}

//  Basic segmentation kernel
__global__ void segment_threshold_kernel(unsigned char* input, unsigned char* mask, int width, int height, int threshold) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= width * height) return;

    mask[idx] = (input[idx] >= threshold) ? 255 : 0;
}

extern "C"
void cuda_segment(unsigned char* input, unsigned char* output_mask, int w, int h, int c, unsigned char threshold) {
    int img_size = w * h;
    unsigned char *d_input, *d_gray, *d_mask;

    cudaMalloc(&d_input, img_size * c);
    cudaMalloc(&d_gray, img_size);
    cudaMalloc(&d_mask, img_size);

    cudaMemcpy(d_input, input, img_size * c, cudaMemcpyHostToDevice);

    int threads = 256;
    int blocks = (img_size + threads - 1) / threads;

    rgb_to_gray_kernel<<<blocks, threads>>>(d_input, d_gray, w, h, c);
    segment_threshold_kernel<<<blocks, threads>>>(d_gray, d_mask, w, h, threshold);

    cudaMemcpy(output_mask, d_mask, img_size, cudaMemcpyDeviceToHost);

    cudaFree(d_input);
    cudaFree(d_gray);
    cudaFree(d_mask);
}