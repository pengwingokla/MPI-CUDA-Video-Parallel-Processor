#include <cuda_runtime.h>
#include <math.h>

// Convert RGB image to grayscale
__global__ void rgb_to_gray(unsigned char* input, unsigned char* gray, int width, int height, int channels) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= width * height) return;
    int i = idx * channels;
    gray[idx] = 0.299f * input[i] + 0.587f * input[i+1] + 0.114f * input[i+2];
}

// Apply Sobel filter
__global__ void sobel_filter(unsigned char* gray, unsigned char* output, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x < 1 || y < 1 || x >= width - 1 || y >= height - 1) return;
    int i = y * width + x;

    int Gx = 
        -1 * gray[(y-1)*width + (x-1)] + 1 * gray[(y-1)*width + (x+1)] +
        -2 * gray[(y  )*width + (x-1)] + 2 * gray[(y  )*width + (x+1)] +
        -1 * gray[(y+1)*width + (x-1)] + 1 * gray[(y+1)*width + (x+1)];

    int Gy = 
        -1 * gray[(y-1)*width + (x-1)] - 2 * gray[(y-1)*width + (x  )] - 1 * gray[(y-1)*width + (x+1)] +
         1 * gray[(y+1)*width + (x-1)] + 2 * gray[(y+1)*width + (x  )] + 1 * gray[(y+1)*width + (x+1)];

    int mag = min(255, (int)sqrtf(Gx * Gx + Gy * Gy));
    output[i] = (unsigned char)mag;
}

extern "C"
void cuda_sobel(unsigned char* input, unsigned char* output, int width, int height, int channels) {
    int img_size = width * height;
    unsigned char *d_input, *d_gray, *d_output;

    cudaMalloc(&d_input, img_size * channels);
    cudaMalloc(&d_gray, img_size);
    cudaMalloc(&d_output, img_size);

    cudaMemcpy(d_input, input, img_size * channels, cudaMemcpyHostToDevice);

    int threads = 256;
    int blocks = (img_size + threads - 1) / threads;
    rgb_to_gray<<<blocks, threads>>>(d_input, d_gray, width, height, channels);

    dim3 threadsPerBlock(16, 16);
    dim3 numBlocks((width + 15)/16, (height + 15)/16);
    sobel_filter<<<numBlocks, threadsPerBlock>>>(d_gray, d_output, width, height);

    cudaMemcpy(output, d_output, img_size, cudaMemcpyDeviceToHost);

    cudaFree(d_input);
    cudaFree(d_gray);
    cudaFree(d_output);
}