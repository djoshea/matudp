# Author: Dan O'Shea dan@djoshea.com 2012

# to get the options in this file, run in Matlab:
# mex('-v', '-f', [matlabroot '/bin/matopts.sh'], '-lrt', 'udpMexReceiver.c')

# pretty print utils
COLOR_NONE=\33[0m
COLOR_WHITE=\33[37;01m
COLOR_BLUE=\33[34;01m

# platform
SYSTEM = $(shell echo `uname -s`)
DEBUGFLAG = -g
#OPTIMFLAG = -O3 
OPTIMFLAG = 


# linux
ifeq ($(SYSTEM), Linux)
OS = lin

# grab the newest version of matlab (well, the last modified directory in /usr/local/MATLAB)
MATLAB_BIN = $(shell ls -t /usr/local/MATLAB/*/bin/matlab | head -1)
MATLAB_ROOT = $(abspath $(dir $(MATLAB_BIN))../)

ECHO = @echo -n "$(COLOR_BLUE)==>$(COLOR_WHITE)"
ECHO_END = ;echo " $(COLOR_BLUE)<==$(COLOR_NONE)"
CXXOSFLAG = -DLINUX
MATLAB_ARCH = glnxa64
# changed rpath-link to rpath to solve dynamic loading issue with libmat.so
LDFLAGS_OS = -lrt -Wl,-rpath,$(MATLAB_ROOT)/bin/$(MATLAB_ARCH) 
endif

# mac os
ifeq ($(SYSTEM), Darwin)
OS = mac
MATLAB_ROOT=/Applications/MATLAB_R2012b.app
ECHO = @echo
ECHO_END = 
CXXOSFLAG = -DMACOS
MATLAB_ARCH = maci64
LDFLAG_OS = 
endif

# compiler options
CXX=clang
CXXFLAGS=-Wall -Wno-comments $(CXXOSFLAG) -DMATLAB_MEX_FILE -std=c99
CXXFLAGS_MEX=-I$(MATLAB_ROOT)/extern/include -I$(MATLAB_ROOT)/simulink/include -D_GNU_SOURCE -I$(MATLAB_ROOT)/extern/include/cpp -DGLNXA64 -DGCC  -DMX_COMPAT_32 $(OPTIMFLAG) -DNDEBUG  
CXXFLAGS_MEX+= -fexceptions -fPIC -fno-omit-frame-pointer
LDFLAGS = $(LDFLAGS_OS) -lpthread
LDFLAGS_MEX = -L$(MATLAB_ROOT)/bin/$(MATLAB_ARCH) -lmat -lmex -lmx -lm -lstdc++ -shared -pthread -Wl,--no-undefined
LDFLAGS_MEX += -Wl,--version-script,$(MATLAB_ROOT)/extern/lib/$(MATLAB_ARCH)/mexFunction.map

# linker options
LD=$(CXX)

# where to locate output files
BUILD_DIR=build
BUILD_DIR_EXTERN=build/extern

# lists of h, cc, and o files
SERIALIZER_SRC_DIR=../serializedDataLogger/src
SERIALIZER_SRC_FILES=writer network parser trie signal utils
C_FILES_EXTERN=$(addprefix $(SERIALIZER_SRC_DIR)/, $(addsuffix .c, $(SERIALIZER_SRC_FILES)))
H_FILES_EXTERN=$(addprefix $(SERIALIZER_SRC_DIR)/, $(addsuffix .h, $(SERIALIZER_SRC_FILES)))
O_FILES_EXTERN=$(addprefix $(BUILD_DIR_EXTERN)/, $(addsuffix .o, $(SERIALIZER_SRC_FILES)))

C_FILES=udpMexReceiver.c
O_FILES=$(BUILD_DIR)/udpMexReceiver.o

# final output
MEX_FILE=udpMexReceiver.mexa64

# debugging, use make print-VARNAME to see value
print-%:
	@echo '$*=$($*)'

############ TARGETS #####################
all: $(MEX_FILE)

# compile .o for each .c, depends also on all .h files
$(BUILD_DIR_EXTERN)/%.o: $(SERIALIZER_SRC_DIR)/%.c $(H_FILES_EXTERN) | $(BUILD_DIR_EXTERN)
	$(ECHO) "Compiling $<" $(ECHO_END)
	$(CXX) $(DEBUGFLAG) -c $(CXXFLAGS) $(CXXFLAGS_MEX) -o $@ $< 

$(BUILD_DIR)/%.o: %.c $(H_FILES_EXTERN) | $(BUILD_DIR)
	$(ECHO) "Compiling $<" $(ECHO_END)
	$(CXX) $(DEBUGFLAG) -c $(CXXFLAGS) $(CXXFLAGS_MEX) -o $@ $< 

# link *.o into executable
$(MEX_FILE): $(O_FILES_EXTERN) $(O_FILES)| $(BIN_DIR)
	$(ECHO) "Linking $(MEX_FILE)" $(ECHO_END)
	$(LD) $(DEBUGFLAG) $(OPTIMFLAG) -o $(MEX_FILE) $(O_FILES) $(O_FILES_EXTERN) $(LDFLAGS) $(LDFLAGS_MEX) 
	$(ECHO) "Built $(MEX_FILE) successfully!" $(ECHO_END)
	
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)
	
$(BUILD_DIR_EXTERN):
	@mkdir -p $(BUILD_DIR_EXTERN)
	
# clean and delete executable
clobber: clean
	@rm -f $(MEX_FILE)

# delete .o files and garbage
clean: 
	$(ECHO) "Cleaning build" $(ECHO_END)
	@rm -rf $(BUILD_DIR) $(BUILD_DIR_EXTERN) *~ core 
