# Compiler settings
CC      = mpicc
NVCC    = nvcc
CFLAGS  = -O2 -Wall
LDFLAGS = -lcudart -lm
INCLUDES = -Iinclude

# Sources
SRC_DIR = src
CUDA_SRC = $(SRC_DIR)/cuda_filter.cu
CUDA_OBJ = cuda_filter.o

FULL_OBJS = \
  main_mpi_cuda.o \
  master.o \
  worker_cuda.o \
  frame_io.o \
  task_queue.o \
  utils.o \
  $(CUDA_OBJ)

# Rules
%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(CUDA_OBJ): $(CUDA_SRC)
	$(NVCC) -c $(CUDA_SRC) -o $@ $(INCLUDES)

full: $(FULL_OBJS)
	$(CC) -o full_exec $(FULL_OBJS) $(LDFLAGS)

clean:
	rm -f *.o full_exec
