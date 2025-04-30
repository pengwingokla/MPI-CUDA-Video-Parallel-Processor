#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image.h"
#include "stb_image_write.h"

unsigned char* load_image(const char* filename, int* w, int* h, int* channels) {
    return stbi_load(filename, w, h, channels, 0);
}

void save_image(const char* filename, unsigned char* data, int w, int h, int channels) {
    stbi_write_jpg(filename, w, h, channels, data, 100);
}

// Get headers: https://github.com/nothings/stb