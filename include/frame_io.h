#ifndef FRAME_IO_H
#define FRAME_IO_H

#ifdef __cplusplus
extern "C" {
#endif

unsigned char* load_image(const char* filename, int* width, int* height, int* channels);
void save_image(const char* filename, const unsigned char* data, int width, int height, int channels);

#ifdef __cplusplus
}
#endif

#endif // FRAME_IO_H