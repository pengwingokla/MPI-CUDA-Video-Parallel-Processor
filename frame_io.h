#ifndef FRAME_IO_H
#define FRAME_IO_H

unsigned char* load_image(const char* filename, int* w, int* h, int* channels);
void save_image(const char* filename, unsigned char* data, int w, int h, int channels);

#endif
