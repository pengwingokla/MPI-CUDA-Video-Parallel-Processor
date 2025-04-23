__global__ void invert_kernel(unsigned char* img, int width, int height, int channels) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int idx = x * channels;
    if (x < width * height) {
        for (int c = 0; c < channels; ++c) {
            img[idx + c] = 255 - img[idx + c];
        }
    }
}

extern "C"
void cuda_invert(unsigned char* data, int w, int h, int c) {
    int total = w * h;
    unsigned char* d_img;
    cudaMalloc(&d_img, total * c);
    cudaMemcpy(d_img, data, total * c, cudaMemcpyHostToDevice);
    invert_kernel<<<(total + 255) / 256, 256>>>(d_img, w, h, c);
    cudaMemcpy(data, d_img, total * c, cudaMemcpyDeviceToHost);
    cudaFree(d_img);
}
