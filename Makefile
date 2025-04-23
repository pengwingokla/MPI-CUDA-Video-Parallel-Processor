CC = mpicc
NVCC = nvcc
CFLAGS = -O2 -Wall
TARGET = classifier

SRCS = main.c master.c worker.c utils.c task_queue.c frame_io.c
OBJS = $(SRCS:.c=.o)

CUDA_SRCS = cuda_filter.cu
CUDA_OBJS = $(CUDA_SRCS:.cu=.o)

%.o: %.cu
	$(NVCC) -c $< -o $@

all: $(TARGET)

$(TARGET): $(OBJS) $(CUDA_OBJS)
	$(CC) -o $@ $(OBJS) $(CUDA_OBJS) -lcudart -lm

clean:
	rm -f *.o $(TARGET)
