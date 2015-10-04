#ifndef WRITER_H_INCLUDED
#define WRITER_H_INCLUDED

#include "utils.h"
#include "signal.h"
#include "signalLogger.h"

typedef struct SignalFileInfo {
	// folder that filename is sitting in
	char filePath[MAX_FILENAME_LENGTH];

	// fully qualified name of file (including filePath)
    char fileName[MAX_FILENAME_LENGTH];

    // trailing name of file (without filePath)
    char fileNameShort[MAX_FILENAME_LENGTH];

    // path to file relative to index file 
    char fileNameRelativeToIndex[MAX_FILENAME_LENGTH];

    // index file contains a list of .mat file names for all protocols, saveTags
    char indexFileName[MAX_FILENAME_LENGTH];
    
    // index file contains a list of .mat file names for a specific protocol, saveTag
    char saveTagIndexFileName[MAX_FILENAME_LENGTH];

    // file handle for index file
    FILE* indexFile;
    FILE* saveTagIndexFile;

} SignalFileInfo; 

const char* getDataRoot();
void setDataRoot(const char* path);
void signalWriterThreadStart();
void signalWriterThreadTerminate();

/////// UDP MEX UTILITIES ////////////////

// builds a struct array with groups(i).signals.signalName containing the data
// and groups(i).version, .meta, .name etc. containing group metadata
// typically used by the udp Mex interface
//
// clear buffers determines whether we clear the timestamp and data buffers
// after polling or simply leave them be
mxArray* buildGroupsArrayForTrial(DataLoggerStatus *, unsigned, bool);
mxArray* buildGroupsArrayForCurrentTrial(bool);

void buildTrialStructForCurrentTrial(mxArray**, mxArray**);
void buildTrialStructForLastCompleteTrial(mxArray**, mxArray**);

#endif

