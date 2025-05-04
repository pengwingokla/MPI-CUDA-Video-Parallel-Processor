# ===========================
# Compiler & Flags
# ===========================
CC      = mpicc
NVCC    = nvcc
CFLAGS  = -O2 -Wall
LDFLAGS = -lcudart -lm
INCLUDES = -Iinclude

# ===========================
# Directories
# ===========================
SRC_DIR = src
BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj

# Ensure build dir exists
$(shell mkdir -p $(OBJ_DIR))

# ===========================
# Common Object Rules
# ===========================
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OBJ_DIR)/cuda_filter.o: $(SRC_DIR)/cuda_filter.cu
	$(NVCC) -c $< -o $@ $(INCLUDES)

# ===========================
# Version 1: Serial (no MPI, no CUDA)
# ===========================
SERIAL_OBJS = $(OBJ_DIR)/main_serial.o $(OBJ_DIR)/frame_io_serial.o $(OBJ_DIR)/utils_serial.o

serial: $(SERIAL_OBJS)
	$(CC) -o exec_serial $^ -lm

$(OBJ_DIR)/frame_io_serial.o: $(SRC_DIR)/frame_io.c
	$(CC) -c $< -o $@ $(INCLUDES) -O2 -Wall

$(OBJ_DIR)/utils_serial.o: $(SRC_DIR)/utils.c
	$(CC) -c $< -o $@ $(INCLUDES) -O2 -Wall

$(OBJ_DIR)/main_serial.o: $(SRC_DIR)/main_serial.c
	$(CC) -c $< -o $@ $(INCLUDES) -O2 -Wall

# ===========================
# Version 2: MPI Only
# ===========================
MPI_ONLY_OBJS = $(OBJ_DIR)/main_mpi.o $(OBJ_DIR)/frame_io.o $(OBJ_DIR)/utils.o

mpi_only: $(MPI_ONLY_OBJS)
	$(CC) -o exec_mpi_only $^ -lm

# ===========================
# Version 3: CUDA Only
# ===========================
CUDA_ONLY_OBJS = \
	$(OBJ_DIR)/main_cuda.o \
	$(OBJ_DIR)/frame_io.o \
	$(OBJ_DIR)/utils.o \
	$(OBJ_DIR)/cuda_filter.o

cuda_only: $(CUDA_ONLY_OBJS)
	$(CC) -o exec_cuda_only $^ $(LDFLAGS)

# ===========================
# Version 4: MPI + CUDA (your current)
# ===========================
FULL_OBJS = \
	$(OBJ_DIR)/main_mpi_cuda.o \
	$(OBJ_DIR)/master.o \
	$(OBJ_DIR)/worker_cuda.o \
	$(OBJ_DIR)/frame_io.o \
	$(OBJ_DIR)/task_queue.o \
	$(OBJ_DIR)/utils.o \
	$(OBJ_DIR)/cuda_filter.o

full: $(FULL_OBJS)
	$(CC) -o exec_full $^ $(LDFLAGS)

# ===========================
# Version 5: CUDA-aware MPI (ambitious)
# ===========================
MPI_CUDA_AWARE_OBJS = $(FULL_OBJS)  # may change later

cuda_aware: $(MPI_CUDA_AWARE_OBJS)
	$(CC) -o cuda_aware_exec $^ $(LDFLAGS)

# ===========================
# Cleanup
# ===========================
.PHONY: clean serial_clean mpi_clean full_clean cuda_clean

clean:
	rm -rf $(OBJ_DIR)/*.o exec_serial exec_mpi_only exec_cuda_only exec_full cuda_aware_exec

serial_clean:
	rm -f exec_serial $(SERIAL_OBJS)

mpi_clean:
	rm -f exec_mpi_only exec_full cuda_aware_exec

cuda_clean:
	rm -f exec_cuda_only
