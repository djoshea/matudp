#ifndef UTILS_H_INCLUDED
#define UTILS_H_INCLUDED

#define MAX_FILENAME_LENGTH 200
#define UNKNOWN_PACKET_COUNT -1

#include <inttypes.h>

#ifdef MATLAB_MEX_FILE
#include "mex.h"
#endif

#include "mat.h"

#include "signal.h"

// performance profiling functions
#ifndef MACOS
void tic(); // reset, start timer
void ticpause(); // pause timer
void ticresume(); // start timer
double toc(); // stop timer, prints elapsed time
double tocCheck();
#endif

#define SECONDS_IN_DAY 86400.0
#define UNIX_EPOCH_OFFSET_SECONDS (719529.0 * SECONDS_IN_DAY)

void diep(const char *s);
mxClassID convertDataTypeIdToMxClassId(uint8_t dataTypeId);
int mkdirRecursive(const char *dir);
wallclock_t getCurrentWallclock();
void convertWallclockToLocalTime(wallclock_t, struct tm*, unsigned*);
datenum_t convertWallclockToMatlabDateNum(wallclock_t);
mxClassID convertDataTypeIdToMxClassId(uint8_t dataTypeId);

// use different malloc and free depending on whether this is compiled into a
// mex function (udpMexReceiver) or standalone (serializedDataLogger)

#if defined(MATLAB_MEX_FILE)

#define MATLAB_MALLOC matlabMallocTemp
#define MATLAB_CALLOC matlabCallocTemp
#define MATLAB_REALLOC matlabReallocTemp
#define MATLAB_FREE matlabFree
void* matlabMallocTemp(size_t size);
void* matlabCallocTemp(size_t sizeElement, size_t nElements);
void* matlabReallocTemp(void* ptr, size_t newsize);
void matlabFree(void* p);

#else

// not in mex function
#define MATLAB_MALLOC malloc
#define MATLAB_CALLOC calloc
#define MATLAB_REALLOC realloc
#define MATLAB_FREE free

#endif

#define MALLOC malloc
#define CALLOC calloc
#define REALLOC realloc
#define FREE free

#ifdef MATLAB_MEX_FILE
#define logInfo(...) (void)0
#define logError(...) fprintf(stderr, __VA_ARGS__)
#else
#define logInfo printf
#define logError(...) fprintf(stderr, __VA_ARGS__)
#endif

void print_trace (void);

#endif // ifndef UTILS_H_INCLUDED
