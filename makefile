##
## CUDA_DIR and LEGACY_CC_PATH may need to be changed, and fewer gpu
## architectures specified in GPU_CODE will make a smaller executable.  These
## variables are all located at the top of the file.
## CSTest is a small utility to extensively test the output of cudasieve.
## see src/cstest.cpp for more details.
##

# Location of the CUDA toolkit
# In ubuntu (all debian based distros?) this is /usr/local/cuda
CUDA_DIR = /usr/local/cuda-9.0
# Location of the *necessary* legacy gcc compiler for nvcc to use.  Maximum
# supported version is 5.4.  In ubuntu, this will be located in /usr/bin/
# from scratch: sudo apt install g++-4.9
# then change LEGACY_CC_PATH to /usr/bin/g++-4.9
LEGACY_CC_PATH = /usr/bin/g++-5
# Compute capability of the target GPU
GPU_ARCH = compute_30
GPU_CODE = sm_30,sm_32,sm_35,sm_37,sm_50,sm_52,sm_53,sm_60,sm_61,sm_62


# Compilers to use
NVCC = $(CUDA_DIR)/bin/nvcc
CC = clang
# Flags for the host compiler
CCFLAGS = -O3 -std=c++11 -c -g
WIGNORE = -Wno-return-stack-address

# Flags for nvcc
# ptxas-options=-dlcm=cg (vs. default of ca) is about a 2% performance gain
NVCC_FLAGS = -ccbin $(LEGACY_CC_PATH) -std=c++11 -arch=$(GPU_ARCH) -code=$(GPU_CODE) \
--ptxas-options=-dlcm=cs

INCLUDES = -I ./include/ -I ./src/ -I $(CUDA_DIR)/include/
LIB_DIR = -L ./
CC_LIBS = -lm -lstdc++
NVCC_LIBS = -lcudart $(CC_LIBS)

CLI_SRC_DIR = src
SRC_DIR = src/CUDASieve
NV_SRCS = src/CUDASieve/launch.cu src/CUDASieve/global.cu src/CUDASieve/primelist.cu
OBJ_DIR = obj

## Cannot use device.cu here because it is #include linked to global.cu!
## this is necessary because the nvcc linker sucks with device code!
#NV_SRCS = src/CUDASieve/global.cu src/CUDASieve/launch.cu src/CUDASieve/device.cu
_MAIN_OBJ = main.o
MAIN_OBJ = $(patsubst %,$(OBJ_DIR)/%,$(_MAIN_OBJ))
_OBJS = host.o cudasieve.o
OBJS = $(patsubst %,$(OBJ_DIR)/%,$(_OBJS))
_NVOBJS = launch.o global.o primelist.o
NVOBJS = $(patsubst %,$(OBJ_DIR)/%,$(_NVOBJS))

MAIN = cudasieve
CS_LIB = lib$(MAIN).a

all: $(MAIN) commands

test: cstest

vars: 
	@echo "      CS_LIB     " $(CS_LIB)
	@echo "        OBJS     " $(OBJS)
	@echo "       NVOBJS     " $(NVOBJS)
	@echo "     SRC_DIR     " $(SRC_DIR)
	@echo "     MAIN_OBJ     " $(MAIN_OBJ)
	@echo "    _MAIN_OBJ     " $(_MAIN_OBJ)

# Tack on a main() function for the CLI
$(MAIN): $(MAIN_OBJ) $(CS_LIB)
	@$(NVCC) $(NVCC_FLAGS) $(CC_LIBS) $(LIB_DIR) -l$(MAIN) $< -o $@
	@echo "     CUDA     " $@

# Linking to make a library
$(CS_LIB): $(OBJS) $(NVOBJS)
	@$(NVCC) $(NVCC_FLAGS) -lib $(INCLUDES) $^ -o $@
	@echo "     CUDALS   " $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cu obj/	
	@echo "     command     " ${NVCC} ${NVCC_FLAGS}
	@$(NVCC) $(NVCC_FLAGS) -c $(INCLUDES) -o $@ $<
	@echo "     CUDA     " $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp obj/
	@echo "        INCLUDES     " $(INCLUDES)
	@$(CC) $(CCFLAGS) $(INCLUDES) $(WIGNORE) -o $@ $<
	@echo "     CXX      " $@

$(OBJ_DIR)/%.o: $(CLI_SRC_DIR)/%.cpp
	@$(CC) $(CCFLAGS) $(INCLUDES) -o $@ $<
	@echo "     CXX      " $@

obj/:
	@mkdir obj/
	@echo "     DIR      " $@
## The cudasieve testing utility depends on boost, openMP and primesieve.
cstest: src/cstest.cpp $(CS_LIB)
	@$(NVCC) $(NVCC_FLAGS) $(INCLUDES) $(LIB_DIR) -O3 -Xcompiler -fopenmp -l$(MAIN) $(NVCC_LIBS) -lprimesieve $< -o cstest
	@echo "     CXX      " $@

commands: $(MAIN)
	@echo ""
	@echo  "    CUDASieve has been compiled. 'cudasieve --help' gives a list of options."
	@echo  "    cstest runs correctness tests.  'make test' to compile"
	@echo  "    Note: cstest depends on boost, openMP, and primesieve libraries"
	@echo  "    'make samples' compiles the one sample.  Currently accepting"
	@echo  "    ideas for more samples.  Have fun!"
	@echo  ""

clean:
	rm -f obj/*.o
	rm -f *.a
	rm -f cudasieve
	rm -f cstest
	rm -f include/CUDASieve/*.gch
	rm -f src/CUDASieve/*.gch

# samples
samples: samples/sumPrimes

samples/% : samples/%.cu $(CS_LIB)
	$(NVCC) $(NVCC_FLAGS) $(CC_LIBS) $(INCLUDES) $(LIB_DIR) -l$(MAIN) $< -o $@
