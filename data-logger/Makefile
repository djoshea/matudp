# Author: Dan O'Shea dan@djoshea.com 2012

# to get the options in this file, run in Matlab:
# mex('-v', '-f', [matlabroot '/bin/matopts.sh'], '-lrt', 'signalLogger.cc', 'writer.cc', 'buffer.cc', 'signal.cc')

# pretty print utils
ifeq ($(COLOR), off)
COLOR_NONE=
COLOR_WHITE=
COLOR_BLUE=
else
COLOR_NONE=\33[0m
COLOR_WHITE=\33[37;01m
COLOR_BLUE=\33[34;01m
endif

# platform
SYSTEM = $(shell echo `uname -s`)
DEBUGFLAG = -g
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
CXX=gcc
#CXX=clang
CXXFLAGS=-Wall -Wno-comments $(CXXOSFLAG) -std=c99
CXXFLAGS_MEX=-I$(MATLAB_ROOT)/extern/include -I$(MATLAB_ROOT)/simulink/include -D_GNU_SOURCE -I$(MATLAB_ROOT)/extern/include/cpp -DGLNXA64 -DGCC  -DMX_COMPAT_32 $(OPTIMFLAG) -DNDEBUG
LDFLAGS = $(LDFLAGS_OS) -lpthread
LDFLAGS_MEX = -L$(MATLAB_ROOT)/bin/$(MATLAB_ARCH) -lmat -lmx -lm 

#-DMATLAB_MEX_FILE 

# linker options
LD=$(CXX)

# where to locate output files
SRC_DIR=src
BUILD_DIR=build
BIN_DIR=bin

# lists of h, cc, and o files
H_FILES=$(wildcard $(SRC_DIR)/*.h)
PCH_FILES=$(patsubst $(SRC_DIR)/%.h, $(BUILD_DIR)/%.pch, $(H_FILES))
C_FILES=$(wildcard $(SRC_DIR)/*.c)
O_FILES=$(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(C_FILES))

# final output
EXECUTABLE=$(BIN_DIR)/signalLogger

# debugging, use make print-VARNAME to see value
print-%:
	@echo '$*=$($*)'

############ TARGETS #####################
all: $(EXECUTABLE) 

.PRECIOUS: $(PCH_FILES)

$(BUILD_DIR)/%.pch: $(SRC_DIR)/%.h $(H_FILES)
	$(ECHO) "Precompiling header $<" $(ECHO_END)
	@$(CXX) -c $(CXXFLAGS) $(CXXFLAGS_MEX) $(DEBUGFLAG) -x c-header $< -o $@ 

# compile .o for each .c, depends also on all .h files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(PCH_FILES) | $(BUILD_DIR)
	$(ECHO) "Compiling $<" $(ECHO_END)
	@$(CXX) -c $(CXXFLAGS) $(CXXFLAGS_MEX) $(DEBUGFLAG) -o $@ $< 

# link *.o into executable
$(EXECUTABLE): $(O_FILES) | $(BIN_DIR)
	$(ECHO) "Linking $(EXECUTABLE)" $(ECHO_END)
	@$(LD) $(OPTIMFLAG) -o $(EXECUTABLE) $(O_FILES) $(LDFLAGS) $(LDFLAGS_MEX) $(DEBUGFLAG)
	$(ECHO) "Built $(EXECUTABLE) successfully!" $(ECHO_END)
	
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# clean and delete executable
clobber: clean
	@rm -f $(EXECUTABLE)

# delete .o files and garbage
clean: 
	$(ECHO) "Cleaning build" $(ECHO_END)
	@rm -f $(PCH_FILES) $(O_FILES) *~ core 
