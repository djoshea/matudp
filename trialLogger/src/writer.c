// MATLAB mat file libraryMeta = mxcreateStruct

#include <string.h>
#include <stdio.h>
#include <stdlib.h> /* For EXIT_FAILURE, EXIT_SUCCESS */
#include "mat.h"

#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <sys/stat.h>

#include "utils.h"
#include "signal.h"
#include "writer.h"
#include "signalLogger.h"

#define WRITE_INTERVAL_USEC 100*1000
#define PATH_SEPARATOR "/"

typedef struct timespec timespec;

pthread_t writerThread;

typedef struct EventTrieInfo {
    char eventName[MAX_SIGNAL_NAME];
    TimestampBuffer tsBuffer;
} EventTrieInfo;

/// PRIVATE DECLARATIONS
char dataRoot[MAX_FILENAME_LENGTH] = "/data/udpTrialLogger";

void * signalWriterThread(void *);
void signalWriterThreadCleanup(void* dummy);
void updateSignalFileInfo(SignalFileInfo*, DataLoggerStatus*, unsigned);

void writeTrialsToMATFile(DataLoggerStatus*);
void writeTrialToMATFile(DataLoggerStatus*, unsigned);
void writeMxArrayToSigFile(mxArray*, mxArray*, const SignalFileInfo *);
void logToSignalIndexFile(const SignalFileInfo* pSigFileInfo);

void buildStructForTrial(DataLoggerStatus*, unsigned, bool, mxArray**, mxArray**);

void addGroupMetaField(mxArray*, const GroupInfo*);
mxArray* setGroupMetaFields(const GroupInfo*, mxArray*, int);
void addSignalMetaField(mxArray*, const SignalDataBuffer *);
mxArray* setSignalMetaFields(const SignalDataBuffer*, mxArray*, int);

bool addGroupTimestampsField(mxArray* mxTrial, const GroupInfo* pg, unsigned trialIdx,
    timestamp_t timeTrialStart, bool useGroupPrefix, unsigned index, unsigned nSamples);
void addSignalDataField(mxArray*, const SignalDataBuffer*, unsigned, bool, unsigned);
void addTrialMetaFields(mxArray*, const DataLoggerStatus*, unsigned);
void addEventGroupFields(mxArray*, mxArray*, const GroupInfo*, unsigned, timestamp_t, bool, unsigned);
SignalFileInfo sigFileInfo;

bool checkDataRootAccessible() {
	// check that we have read and write access to the data root
	return access( dataRoot, R_OK | W_OK ) != -1;
}

const char* getDataRoot() {
    return dataRoot;
}

void setDataRoot(const char* path) {
    strncpy(dataRoot, path, MAX_FILENAME_LENGTH);

    // strip trailing slash if found
    int last = strnlen(dataRoot, MAX_FILENAME_LENGTH) - 1;
    if(dataRoot[last] == '\\')
        dataRoot[last] = '\0';

    printf("Data root is now %s\n", dataRoot);
}

// this function is run as a separate thread from the main() derived thread
// the main() thread reads packets off the network, assembles and parses them
// and pushes signals onto the signal buffer queue
//
// this thread's job is to pull signals off the signal buffer, build Matlab mxArrays
// which contain their data, and write them to disk periodically as .mat files
void * signalWriterThread(void * dummy){
    pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
    pthread_setcanceltype(PTHREAD_CANCEL_DEFERRED, NULL);
    pthread_cleanup_push(signalWriterThreadCleanup, NULL);

    DataLoggerStatus* dlStatus;

    while(1)
    {
        // first we check the retired statuses buffer to see if there are any old
        // trials to write

        while((dlStatus = controlPopRetiredStatus()) != NULL) {
            writeTrialsToMATFile(dlStatus);
            freeDataLoggerStatus(dlStatus);
        }

        dlStatus = controlGetCurrentStatus();
        if(dlStatus != NULL)
            writeTrialsToMATFile(dlStatus);

        pthread_testcancel();
        usleep(WRITE_INTERVAL_USEC);
    }

    pthread_cleanup_pop(0);

    return NULL;
}

void signalWriterThreadCleanup(void* dummy) {
    printf("SignalWriteThread: Cleaning up\n");
    if(sigFileInfo.indexFile != NULL)
        fclose(sigFileInfo.indexFile);
}

void signalWriterThreadStart() {
    // Start File Writer Thread
    int rcWriter = pthread_create(&writerThread, NULL, signalWriterThread, NULL);
    if (rcWriter) {
        printf("ERROR! Return code from pthread_create() is %d\n", rcWriter);
        exit(-1);
    }
}

void signalWriterThreadTerminate() {
    pthread_cancel(writerThread);
    pthread_join(writerThread, NULL);
}

void writeTrialsToMATFile(DataLoggerStatus* dlStatus)
{
    unsigned trialIdx;
    while((trialIdx = controlGetNextCompleteTrialToWrite(dlStatus)) != -1)
        writeTrialToMATFile(dlStatus, trialIdx);
}

void writeTrialToMATFile(DataLoggerStatus* dlStatus, unsigned trialIdx)
{
    mxArray *mxTrial, *mxMeta;
    updateSignalFileInfo(&sigFileInfo, dlStatus, trialIdx);

    buildStructForTrial(dlStatus, trialIdx, true, &mxTrial, &mxMeta);
    writeMxArrayToSigFile(mxTrial, mxMeta, &sigFileInfo);
    printf("Wrote trial %d to %s\n", dlStatus->byTrial[trialIdx].trialId,
            sigFileInfo.fileNameShort);

    logToSignalIndexFile(&sigFileInfo);

    mxDestroyArray(mxTrial);
    mxDestroyArray(mxMeta);
}

void buildTrialStructForCurrentTrial(mxArray**pMxTrial, mxArray**pMxMeta) {
    DataLoggerStatus *dlStatus = controlGetCurrentStatus();
    if(dlStatus == NULL) {
        // shouldn't happen...fill both with empty arrays
        logError("No current data logger status");
        *pMxTrial = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
        *pMxMeta = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
        return;
    }

    unsigned trialIdx = dlStatus->currentTrial;
    buildStructForTrial(dlStatus, trialIdx, false, pMxTrial, pMxMeta);
}

void buildTrialStructForLastCompleteTrial(mxArray**pMxTrial, mxArray**pMxMeta) {
    DataLoggerStatus *dlStatus = controlGetCurrentStatus();
    if(dlStatus == NULL) {
        // shouldn't happen...fill both with empty arrays
        logError("No current data logger status");
        *pMxTrial = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
        *pMxMeta = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
        return;
    }

    unsigned trialIdx = controlGetNextCompleteTrialToWrite(dlStatus);
    if(trialIdx == -1) {
        // no complete trial, fill both with empty arrays
        *pMxTrial = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
        *pMxMeta = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);
    } else {
        // build trial/meta array, mark as complete, clear buffers
        buildStructForTrial(dlStatus, trialIdx, true, pMxTrial, pMxMeta);
    }
}

// builds a trial struct in *pMxTrial and meta data struct in *pMxMeta
// if clearBuffers is true, each timestamp buffer, signal data buffer will be cleared
// and the trial will be marked as written
void buildStructForTrial(DataLoggerStatus* dlStatus, unsigned trialIdx, bool clearBuffers,
        mxArray ** pMxTrial, mxArray **pMxMeta) {
    DataLoggerStatusByTrial *trialStatus = dlStatus->byTrial + trialIdx;

    // iterate over the group trie
    GroupTrie* gtrie = dlStatus->gtrie;

    const char* metaFields[] = {"groups", "signals"};
    mxArray* mxTrial;
    mxArray* mxMeta;
    mxArray* mxGroupMeta;
    mxArray* mxSignalMeta;

    // outer trial struct
    mxTrial = mxCreateStructMatrix(1,1,0,NULL);

    // outer meta struct
    mxMeta = mxCreateStructMatrix(1, 1, 2, metaFields);
    // meta.groups struct
    mxGroupMeta = mxCreateStructMatrix(1,1,0,NULL);
    // meta.signals struct
    mxSignalMeta = mxCreateStructMatrix(1,1,0,NULL);

    // add fields like .protocol, subject, duration, etc.
    // to trial (not the meta struct, sorry for the name collision)
    addTrialMetaFields(mxTrial, dlStatus, trialIdx);

    // all timestamps written to the struct will be relative to this start time
    timestamp_t trialStartTime = trialStatus->timestampStart;

    GroupTrie* groupNode = getFirstGroupNode(gtrie);
    SignalDataBuffer* psdb;
    unsigned iSignal = 0, iGroup = 0;
    while(groupNode != NULL) {
        GroupInfo* pg = (GroupInfo*)groupNode->value;
        unsigned nSamples = pg->tsBuffers[trialIdx].nSamples;

        // build an mxArray containing meta data about this group
        addGroupMetaField(mxGroupMeta, (const GroupInfo*)pg);

        if(pg->type == GROUP_TYPE_ANALOG) {
            // build an mxArray containing timestamps for this group
            // true is for useGroupPrefix, which we should do always for the time field or else there
            // will be name collisions
            addGroupTimestampsField(mxTrial, (const GroupInfo*)pg, trialIdx, trialStartTime, true, 0, nSamples);
        }

        if(pg->type != GROUP_TYPE_EVENT) {
			for(unsigned i = 0; i < pg->nSignals; i++) {
				psdb = pg->signals[i];
				if(psdb == NULL) continue;

				// these have been accounted for by addGroupTimestampsField above
				if(psdb->type != SIGNAL_TYPE_TIMESTAMP && psdb->type != SIGNAL_TYPE_TIMESTAMPOFFSET) {
					// add to meta.signals.(name)
					 addSignalMetaField(mxSignalMeta, (const SignalDataBuffer*) psdb);

					// build an mxArray for this signal's data
					// don't use group prefix on the signal and hope there are no collisions
					// todo CHECK FOR COLLISIONS?
					addSignalDataField(mxTrial, psdb, trialIdx, false, nSamples);
				}

				// clear the timeseries buffer as these samples are no longer needed
				if(clearBuffers)
					clearSampleBuffer(psdb->buffers + trialIdx);

				iSignal++;
			}
        } else {
        	// event group type
        	// for event groups, the individual samples will be event names
			// so we write a new field with each event in it containing the timestamps encountered
			mxArray* mxThisGroupMeta = mxGetField(mxGroupMeta, 0, pg->name);
			addEventGroupFields(mxTrial, mxThisGroupMeta, pg, trialIdx,
				trialStartTime, false, 0);

			// clear the timeseries buffer as these samples are no longer needed
			if(clearBuffers) {
				for(unsigned i = 0; i < pg->nSignals; i++) {
					psdb = pg->signals[i];
					if(psdb == NULL) continue;
					clearSampleBuffer(psdb->buffers + trialIdx);
				}
			}
        }

        // clear the group's timestamp buffer
        if(clearBuffers)
            clearTimestampBuffer(pg->tsBuffers + trialIdx);

        // advance to the next group on the trie
        groupNode = getNextGroupNode(groupNode);

        iGroup++;
    }

    // set meta.groups = mxGroupMeta
    mxSetField(mxMeta, 0, "groups", mxGroupMeta);
    mxSetField(mxMeta, 0, "signals", mxSignalMeta);

    // mark that trial as no longer being actively written
    if(clearBuffers)
        controlMarkTrialWritten(dlStatus, trialIdx);

    // assign the output argument mxArrays
    if(pMxTrial != NULL)
        *pMxTrial = mxTrial;

    if(pMxMeta != NULL)
        *pMxMeta = mxMeta;
}

// based on the trial we're currently writing to disk,
void updateSignalFileInfo(SignalFileInfo* pSignalFile, DataLoggerStatus* pStatus, unsigned trialIdx)
{
    DataLoggerStatusByTrial* trialStatus = pStatus->byTrial + trialIdx;

    unsigned msec;
    struct tm timeInfo;

    convertWallclockToLocalTime(trialStatus->wallclockStart, &timeInfo, &msec);

	// append the date as a folder onto dataRoot
    char dateFolderBuffer[MAX_FILENAME_LENGTH];
    strftime(dateFolderBuffer, MAX_FILENAME_LENGTH, "%Y-%m-%d", &timeInfo);

    // build pathBufferIndex as   dataRoot/storeName/subject/YYYYMMDD/
    // build pathBufferSaveTag as dataRoot/storeName/subject/YYYYMMDD/protocol/saveTag#/
    char pathBufferIndex[MAX_FILENAME_LENGTH];
    char pathBufferTrial[MAX_FILENAME_LENGTH];
    snprintf(pathBufferIndex, MAX_FILENAME_LENGTH,
            "%s/%s/%s/%s", dataRoot, pStatus->dataStore, pStatus->subject, dateFolderBuffer);
    snprintf(pathBufferTrial, MAX_FILENAME_LENGTH,
            "%s/%s/saveTag%03d", pathBufferIndex, pStatus->protocol, pStatus->saveTag);

    // check that this data directory exists if it's changed from last time
    if(strncmp(pathBufferTrial, pSignalFile->filePath, MAX_FILENAME_LENGTH) != 0)
    {
        // path has changed, need to check that this path exists, and/or create it
        if (access( pathBufferTrial, R_OK | W_OK ) == -1)
        {
            // this new path doesn't exist or we can't access it --> mkdir it
            int failed = mkdirRecursive(pathBufferTrial);
            if(failed)
                diep("Error creating trial data directory");
        }

        // update the filePath so we don't try to create it again
        strncpy(pSignalFile->filePath, pathBufferTrial, MAX_FILENAME_LENGTH);
        logInfo("Updating trial data dir : %s\n", pSignalFile->filePath);
    }

    // now check the index file to make sure it exists
    // the index file is simply a list of .mat files written to this directory
    // which makes it is easy for other programs to detect when these files
    // are added, rather than having to stat the whole directory repeatedly
    char indexFileBuffer[MAX_FILENAME_LENGTH];
    snprintf(indexFileBuffer, MAX_FILENAME_LENGTH,
            "%s/trialIndex.txt", pathBufferIndex);

    char saveTagIndexFileBuffer[MAX_FILENAME_LENGTH];
    snprintf(saveTagIndexFileBuffer, MAX_FILENAME_LENGTH,
            "%s/trialIndex.txt", pathBufferTrial);

    // check whether the index file is the same as last time
    if(strncmp(indexFileBuffer, pSignalFile->indexFileName, MAX_FILENAME_LENGTH) != 0)
    {
        // it's changed from last time
        strncpy(pSignalFile->indexFileName, indexFileBuffer, MAX_FILENAME_LENGTH);
        logInfo("Updating trial index file : %s\n", pSignalFile->indexFileName);

        pSignalFile->indexFile = fopen(pSignalFile->indexFileName, "a");

        if(pSignalFile->indexFile == NULL)
        {
            diep("Error opening index file.");
        }
    }

    // check whether the save tag index file is the same as last time
    if(strncmp(saveTagIndexFileBuffer, pSignalFile->saveTagIndexFileName, MAX_FILENAME_LENGTH) != 0)
    {
        // it's changed from last time
        strncpy(pSignalFile->saveTagIndexFileName, saveTagIndexFileBuffer, MAX_FILENAME_LENGTH);
        logInfo("Updating save-tag index file : %s\n", pSignalFile->saveTagIndexFileName);

        pSignalFile->saveTagIndexFile = fopen(pSignalFile->saveTagIndexFileName, "a");

        if(pSignalFile->saveTagIndexFile == NULL)
            diep("Error opening index file.");
    }
    // create a unique mat file name based on <subject>_protocol_<date.time.msec>_id<trialId>.mat
    char fileTimeBuffer[MAX_FILENAME_LENGTH];
    strftime(fileTimeBuffer, MAX_FILENAME_LENGTH, "%Y%m%d.%H%M%S", &timeInfo);

    // assemble short file name without path
    snprintf(pSignalFile->fileNameShort, MAX_FILENAME_LENGTH,
            "%s_%s_id%06d_time%s.%03d.mat", pStatus->subject, pStatus->protocol,
            trialStatus->trialId, fileTimeBuffer, msec);

    // path relative to index file, e.g. protocol/saveTag#/fileName.mat
    snprintf(pSignalFile->fileNameRelativeToIndex, MAX_FILENAME_LENGTH,
            "%s/saveTag%03d/%s", pStatus->protocol, pStatus->saveTag, pSignalFile->fileNameShort);

    // assemble file name with path
    snprintf(pSignalFile->fileName, MAX_FILENAME_LENGTH,
            "%s/%s", pSignalFile->filePath, pSignalFile->fileNameShort);
}

void logToSignalIndexFile(const SignalFileInfo* pSigFileInfo)
{
    // write the string to the index file
    if(pSigFileInfo->indexFile == NULL)
        diep("Index file not opened\n");
    if(pSigFileInfo->saveTagIndexFile == NULL)
        diep("Index file not opened\n");

    fprintf(pSigFileInfo->indexFile, "%s\n", pSigFileInfo->fileNameRelativeToIndex);
    fflush(pSigFileInfo->indexFile);
    fprintf(pSigFileInfo->saveTagIndexFile, "%s\n", pSigFileInfo->fileNameShort);
    fflush(pSigFileInfo->saveTagIndexFile);
}

void writeMxArrayToSigFile(mxArray* mxTrial, mxArray* mxMeta, const SignalFileInfo *pSigFileInfo)
{
    int error;

	// open the file
	MATFile* pmat = matOpen(pSigFileInfo->fileName, "w");

	if(pmat == NULL)
		diep("Error opening MAT file");

	// put variable in file
	error = matPutVariable(pmat, "trial", mxTrial);
	if(error)
		diep("Error putting variable in MAT file");
	error = matPutVariable(pmat, "meta", mxMeta);
	if(error)
		diep("Error putting variable in MAT file");

	// close the file
	matClose(pmat);
}

void addTrialMetaFields(mxArray* mxTrial, const DataLoggerStatus* dlStatus, unsigned trialIdx) {
    // add subject field
    unsigned fieldNum;
    mxArray* mxTemp;

    const DataLoggerStatusByTrial* trialStatus = dlStatus->byTrial + trialIdx;

    timestamp_t timestampStart = trialStatus->timestampStart;
    timestamp_t timestampEnd = trialStatus->timestampEnd;
    struct tm timeInfo;
    unsigned msec;

    datenum_t wallclockStart = convertWallclockToMatlabDateNum(trialStatus->wallclockStart);
    convertWallclockToLocalTime(trialStatus->wallclockStart, &timeInfo, &msec);

    fieldNum = mxAddField(mxTrial, "subject");
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxCreateString(dlStatus->subject));

    fieldNum = mxAddField(mxTrial, "protocol");
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxCreateString(dlStatus->protocol));

    fieldNum = mxAddField(mxTrial, "protocolVersion");
    mxTemp = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
    memcpy(mxGetData(mxTemp), &dlStatus->protocolVersion, sizeof(uint32_t));
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTemp);

    fieldNum = mxAddField(mxTrial, "dataStore");
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxCreateString(dlStatus->dataStore));

    // add date as "YYYYMMDD" number
    fieldNum = mxAddField(mxTrial, "date");
    unsigned date = (timeInfo.tm_year+1900) * 10000 + (timeInfo.tm_mon+1) * 100 + timeInfo.tm_mday;
    mxTemp = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
    memcpy(mxGetData(mxTemp), &date, sizeof(uint32_t));
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTemp);

    fieldNum = mxAddField(mxTrial, "saveTag");
    mxTemp = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
    ((uint32_t*)mxGetData(mxTemp))[0] = dlStatus->saveTag;
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTemp);

    fieldNum = mxAddField(mxTrial, "trialId");
    mxTemp = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
    ((uint32_t*)mxGetData(mxTemp))[0] = trialStatus->trialId;
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTemp);

    // generate unique trialId string using Subject_Date_Protocol_SaveTag_trialId
    char trialIdStr[MAX_STRING];
    char dateStr[MAX_STRING];
    strftime(dateStr, MAX_STRING, "%Y%m%d", &timeInfo);
    snprintf(trialIdStr, MAX_STRING, "%s_%s_%s_saveTag%03u_trial%04u",
            dlStatus->subject, dateStr, dlStatus->protocol,
            dlStatus->saveTag, trialStatus->trialId);

    fieldNum = mxAddField(mxTrial, "trialIdStr");
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxCreateString(trialIdStr));

    // save wallclock matlab datenums for time and stop timestamps
    fieldNum = mxAddField(mxTrial, "wallclockStart");
    mxTemp = mxCreateNumericMatrix(1, 1, mxDOUBLE_CLASS, mxREAL);
    ((double*)mxGetData(mxTemp))[0] = wallclockStart;
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTemp);

    fieldNum = mxAddField(mxTrial, "tsStart");
    mxTemp = mxCreateNumericMatrix(1, 1, mxDOUBLE_CLASS, mxREAL);
    ((double*)mxGetData(mxTemp))[0] = timestampStart;
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTemp);

    fieldNum = mxAddField(mxTrial, "tsStop");
    mxTemp = mxCreateNumericMatrix(1, 1, mxDOUBLE_CLASS, mxREAL);
    ((double*)mxGetData(mxTemp))[0] = timestampEnd;
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTemp);

    // compute duration in ms, add one to match timestamps 0...N
    double duration = round((trialStatus->timestampEnd - trialStatus->timestampStart)) + 1;
    fieldNum = mxAddField(mxTrial, "duration");
    mxTemp = mxCreateNumericMatrix(1, 1, mxDOUBLE_CLASS, mxREAL);
    ((double*)mxGetData(mxTemp))[0] = duration;
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTemp);

    fieldNum = mxAddField(mxTrial, "format");
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxCreateString("tds3"));

    fieldNum = mxAddField(mxTrial, "timeUnits");
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxCreateString("ms"));
}

void addGroupMetaField(mxArray* mxGroupMeta, const GroupInfo *pg) {
    mxArray * thisGroupsField = setGroupMetaFields(pg, NULL, 0);

    // add this group as a field to mxGroupMeta
    unsigned fieldNum = mxAddField(mxGroupMeta, pg->name);
    mxSetFieldByNumber(mxGroupMeta, 0, fieldNum, thisGroupsField);
}

// if mxMeta == NULL, create a scalar struct with meta fields within
// else set mxMeta(index).fields with the meta data
// returns the resulting mxMeta
mxArray* setGroupMetaFields(const GroupInfo* pg, mxArray* mxMeta, int index) {
    mwSize nFields = 5;
    // NOTE: IF YOU CHANGE THESE, ALSO CHANGE THE FIELDS IN buildGroupsForTrial
    // THESE MUST BE A SUBSET OF THOSE FIELDS
    const char* fieldNames[] = {"name", "type", "configHash", "version", "signalNames"};

    if(mxMeta == NULL)
        mxMeta = mxCreateStructMatrix(1,1, nFields, fieldNames);

    mxArray* mxGroup_name;
    mxArray* mxGroup_type;
    mxArray* mxGroup_configHash;
    mxArray* mxGroup_version;
    mxArray* mxGroup_signalNames;

    // set the .name field in the mxGroups array
    mxGroup_name = mxCreateString(pg->name);
    mxSetField(mxMeta, index, "name", mxGroup_name);

    // set the .type field
    // convert uint8_t code to string here using getGroupTypeName
    char groupTypeName[MAX_GROUP_TYPE_NAME];
    getGroupTypeName(pg->type, groupTypeName);
    mxGroup_type = mxCreateString(groupTypeName);
    mxSetField(mxMeta, index, "type", mxGroup_type);

    // set the .configHash field
    mxGroup_configHash = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
    memcpy(mxGetData(mxGroup_configHash), &pg->configHash, sizeof(uint32_t));
    mxSetField(mxMeta, index, "configHash", mxGroup_configHash);

    // set the .version field
    mxGroup_version = mxCreateNumericMatrix(1, 1, mxUINT16_CLASS, mxREAL);
    memcpy(mxGetData(mxGroup_version), &pg->version, sizeof(uint16_t));
    mxSetField(mxMeta, index, "version", mxGroup_version);

    // put the names of all signals in this group in N x 1 cell array
    // (event groups use a different naming convention and are added in a different function)
    if(pg->type != GROUP_TYPE_EVENT) {
        mxGroup_signalNames = mxCreateCellMatrix(pg->nSignals, 1);
        for(unsigned iSignal = 0; iSignal < pg->nSignals; iSignal++) {
            mxSetCell(mxGroup_signalNames, iSignal, mxCreateString(pg->signals[iSignal]->name));
        }
        mxSetField(mxMeta, index, "signalNames", mxGroup_signalNames);
    }

    return mxMeta;
}

void addSignalMetaField(mxArray* mxSignalMeta, const SignalDataBuffer *psdb) {
    mxArray * thisSignalField = setSignalMetaFields(psdb, NULL, 0);

    // add this group as a field to mxGroupMeta
    unsigned fieldNum = mxAddField(mxSignalMeta, psdb->name);
    mxSetFieldByNumber(mxSignalMeta, 0, fieldNum, thisSignalField);
}

// if mxMeta == NULL, create a scalar struct with meta fields within
// else set mxMeta(index).fields with the meta data
// returns the resulting mxMeta
mxArray* setSignalMetaFields(const SignalDataBuffer* psdb, mxArray* mxMeta, int index) {
    mwSize nFields = 6;
    const char* fieldNames[] = {"type", "units", "groupName", "timeFieldName", "concatDimension", "isVariableSize"};

    if(mxMeta == NULL)
        mxMeta = mxCreateStructMatrix(1,1, nFields, fieldNames);

    mxArray* mxSignal_type;
    mxArray* mxSignal_groupName;
    mxArray* mxSignal_timeFieldName;
    mxArray* mxSignal_units;
    mxArray* mxSignal_concatDimension;
    mxArray* mxSignal_isVariableSize;

    // set the .type field
    // convert uint8_t code to string here using getSignalTypeName
    char signalTypeName[MAX_SIGNAL_TYPE_NAME];
    getSignalTypeName(psdb->type, signalTypeName);
    mxSignal_type = mxCreateString(signalTypeName);
    mxSetField(mxMeta, index, "type", mxSignal_type);

    // set the .units field
    mxSignal_units = mxCreateString(psdb->units);
    mxSetField(mxMeta, index, "units", mxSignal_units);

    // set the .groupName field
    mxSignal_groupName = mxCreateString(psdb->pGroupInfo->name);
    mxSetField(mxMeta, index, "groupName", mxSignal_groupName);

    // set the .timeFieldName field to "groupName_time"
    char timeFieldName[MAX_SIGNAL_NAME];
    snprintf(timeFieldName, MAX_SIGNAL_NAME, "%s_time", psdb->pGroupInfo->name);
    mxSignal_timeFieldName = mxCreateString(timeFieldName);
    mxSetField(mxMeta, index, "timeFieldName", mxSignal_timeFieldName);

    // set the .concatDimension field
    mxSignal_concatDimension = mxCreateNumericMatrix(1, 1, mxUINT8_CLASS, mxREAL);
    memcpy(mxGetData(mxSignal_concatDimension), &psdb->concatDimension, sizeof(uint8_t));
    mxSetField(mxMeta, index, "concatDimension", mxSignal_concatDimension);

    // set the .isVariableSize field
    mxSignal_isVariableSize = mxCreateLogicalScalar((mxLogical)psdb->isVariable);
    mxSetField(mxMeta, index, "isVariableSize", mxSignal_isVariableSize);

    return mxMeta;
}

// there are two alternative ways of getting timestamps for a given group
// by default, the timestamps come from the times when a given group was received by the
// data logger, using the uint32 timestamp received at that time
//
// alternatively, a group can contain a signal with type == SIGNALTYPE_TIMESTAMPS (uint32)
// and/or a signal with type == SIGNALTYPE_TIMESTAMPOFFSETS (single). If either of these are specified
// the timestamps will be computed using these fields. Specifically, the contents of the timestamps field
// will replace the singular timestamp received with the group header (allowing multiple samples
// to be sent on each tick), and the contents of the timestampOffsets field will be used to offset the values
// in timestamps by some fractional amount (allowing sub millisecond resolution)

bool addGroupTimestampsField(mxArray* mxTrial, const GroupInfo* pg, unsigned trialIdx,
    timestamp_t timeTrialStart, bool useGroupPrefix, unsigned index, unsigned nSamples) {

    // build groupName_time field name
    char fieldName[MAX_SIGNAL_NAME];
    if(useGroupPrefix)
        snprintf(fieldName, MAX_SIGNAL_NAME, "%s_time", pg->name);
    else
        strcpy(fieldName, "time");

    timestamp_t *pTimestampsBase = pg->tsBuffers[trialIdx].timestamps;
    uint32_t nTimestampsBase = pg->tsBuffers[trialIdx].nSamples;

    // create the matlab array to hold the timestamps, use double as the type
    mxArray* mxTimestamps = mxCreateNumericMatrix(nTimestampsBase, 1, mxDOUBLE_CLASS, mxREAL);

    // enter the timestamps minus the trial start into the array
    double_t* buffer = (double_t*)mxGetData(mxTimestamps);
    // no offsets, subtract trial start and round to ms (should be integer anyway)
    for(unsigned i = 0; i < nTimestampsBase; i++)
        buffer[i] = pTimestampsBase[i] - timeTrialStart;

    // add to trial struct
    int fieldNum;
    fieldNum = mxGetFieldNumber(mxTrial, fieldName);
    if(fieldNum == -1)
        fieldNum = mxAddField(mxTrial, fieldName);

    mxSetFieldByNumber(mxTrial, index, fieldNum, mxTimestamps);

    return true;
}

void addSignalDataField(mxArray* mxTrial, const SignalDataBuffer* psdb, unsigned trialIdx,
        bool useGroupPrefix, unsigned nSamples)
{
    mxArray* mxData;

    // field name is groupName_signalName
    char fieldName[MAX_SIGNAL_NAME];
    if(useGroupPrefix)
        snprintf(fieldName, MAX_SIGNAL_NAME, "%s_%s", psdb->pGroupInfo->name, psdb->name);
    else
        strncpy(fieldName, psdb->name, MAX_SIGNAL_NAME);

    const SampleBuffer* ptb = psdb->buffers + trialIdx;
    mwSize ndims = (mwSize)psdb->nDims;
    mwSize dims[MAX_SIGNAL_NDIMS+1];
    unsigned nBytesData, totalElements;

    if(nSamples > ptb->nSamples)
        nSamples = ptb->nSamples;

    // to store the matlab data type
    mxClassID cid = convertDataTypeIdToMxClassId(psdb->dataTypeId);
    unsigned bytesPerElement = getSizeOfDataTypeId(psdb->dataTypeId);

    if(psdb->dataTypeId == DTID_CHAR && (psdb->pGroupInfo->type == GROUP_TYPE_PARAM || psdb->type == SIGNAL_TYPE_PARAM)) {
        // string received as part of param group or as param signal, place as string
        char strBuffer[MAX_SIGNAL_SIZE+1];

        if(nSamples == 0)
            mxData = mxCreateString("");
        else {
            // first copy string into buffer, then zero terminate it
            unsigned bytesThisSample = ptb->bytesEachSample[0];
            if(bytesThisSample > MAX_SIGNAL_SIZE) {
                bytesThisSample = MAX_SIGNAL_SIZE;
                logError("Overflow on signal %s", psdb->name);
            }
            memcpy(strBuffer, ptb->data, bytesThisSample);
            strBuffer[bytesThisSample] = '\0';

            // now copy it into a matlab string and store in the cell array
            mxData = mxCreateString(strBuffer);
        }
    } else {
    	// determine whether we can concatenate this signal along some axis
    	bool concat = psdb->concatLastDim;   	// first check whether the user requested it

    	// then check the dimensions of the signals to see if this is possible
    	// concatenation is allowed only if only the last dimension changes size among the samples
    	// i.e. the non-concatenation dimensions must match exactly
    	for(int d = 0; d < psdb->nDims - 1; d++) {
    		if(psdb->dimChangesSize[d]) {
    			concat = false;
    			break;
    		}
    	}

    	if(concat) {
			// concatenateable variable signal

			// determine the dimensions of the concatenated signal.
    		totalElements = ptb->nDataBytes / bytesPerElement;
			unsigned totalElementsPenultimateDims = 1;
			for(int i = 0; i < (int)ndims - 1; i++)
			{
				dims[i] = (mwSize)(psdb->dims[i]);
				totalElementsPenultimateDims *= dims[i];
			}
			dims[ndims-1] = totalElements / totalElementsPenultimateDims;

			// convert row vectors to column vectors
			if(ndims == 2 && dims[0] == 1) {
				dims[0] = dims[1];
				dims[1] = 1;
				ndims = 1;
			}

			nBytesData = totalElements * bytesPerElement;

			// create and fill a numeric tensor
			if(psdb->dataTypeId == DTID_LOGICAL)
				mxData = mxCreateLogicalArray(ndims, dims);
			else if(psdb->dataTypeId == DTID_CHAR)
				mxData = mxCreateCharArray(ndims, dims);
			else
				mxData = mxCreateNumericArray(ndims, dims, cid, mxREAL);

			memcpy(mxGetData(mxData), ptb->data, nBytesData);

		} else {
			// data is char or samples have different sizes, put each in a cell array
			mxData = mxCreateCellMatrix(nSamples, 1);

			if(psdb->dataTypeId == DTID_CHAR) {
				// special case char array: make 1 x N char array for each string and store these into
				// a Nsamples x 1 cell array
				char* dataPtr = (char*)ptb->data;
				char strBuffer[MAX_SIGNAL_SIZE+1];

				for(unsigned iSample = 0; iSample < nSamples; iSample++) {
					// first copy string into buffer, then zero terminate it
					unsigned bytesThisSample = ptb->bytesEachSample[iSample];
					// TODO add memory overflow check here
					memcpy(strBuffer, dataPtr, bytesThisSample);
					strBuffer[bytesThisSample] = '\0';

					// now copy it into a matlab string and store in the cell array
					mxSetCell(mxData, iSample, mxCreateString(strBuffer));

					// advance the data pointer
					dataPtr+=bytesThisSample;
				}

			} else {
				mxArray* mxSampleData;

				// variable size numeric signal
				totalElements = 1;
				// get size along all dimensions but last which is variable
				for(int i = 0; i < (int)ndims - 1; i++)
				{
					dims[i] = (mwSize)(psdb->dims[i]);
					totalElements *= dims[i];
				}

				// loop over each sample
				for(unsigned iSample = 0; iSample < nSamples; iSample++) {
					unsigned bytesThisSample = ptb->bytesEachSample[iSample];
					// calculate last dimension by division
					dims[ndims-1] = bytesThisSample / bytesPerElement / totalElements;
					nBytesData = totalElements*dims[ndims-1]*bytesPerElement;

					// create and fill a numeric tensor
					if(psdb->dataTypeId == DTID_LOGICAL)
						mxSampleData = mxCreateLogicalArray(ndims, dims);
					else
						mxSampleData = mxCreateNumericArray(ndims, dims, cid, mxREAL);

					memcpy(mxGetData(mxSampleData), ptb->data, nBytesData);

					// and assign it into the cell
					mxSetCell(mxData, iSample, mxSampleData);
				}
			}
		}
    }

    // add to trial struct
    unsigned fieldNum = mxAddField(mxTrial, fieldName);
    mxSetFieldByNumber(mxTrial, 0, fieldNum, mxData);
}

void addEventGroupFields(mxArray* mxTrial, mxArray* mxGroupMeta,
    const GroupInfo* pg, unsigned trialIdx, timestamp_t timeTrialStart,
    bool useGroupPrefix, unsigned groupMetaIndex)
{
    // field names will be groupName_<eventName>
    // but the signal always comes in as .eventName and the contents are the name
    // of the event
    //
    // so: build up a trie where the eventName is the key and a TimestampBuffer is the value
    Trie* eventTrie = trie_create();
    Trie* trieNode;

    // get timestamp buffer from group buffer
    const TimestampBuffer* groupTimestamps = pg->tsBuffers + trialIdx;
    const char* groupName = pg->name;

    // for now check that the event group has only 1 signal and it's type is EventName
    bool printError = false;
    if(pg->nSignals != 1)
    	printError = true;
    else if(pg->signals[0]->type != SIGNAL_TYPE_EVENTNAME)
    	printError = true;
    if(printError) {
    	logError("Event groups must have 1 signal of type event name");
    	return;
    }

    const SignalDataBuffer*psdb = pg->signals[0];
    const SampleBuffer* ptb = psdb->buffers + trialIdx;
    char eventName[MAX_SIGNAL_NAME];

    char* dataPtr = (char*)ptb->data;
    for(unsigned iSample = 0; iSample < ptb->nSamples; iSample++) {
        // first copy string into buffer, then zero terminate it
        unsigned bytesThisSample = ptb->bytesEachSample[iSample];

        // TODO add overflow detection
        memcpy(eventName, dataPtr, bytesThisSample);
        dataPtr += bytesThisSample;
        eventName[bytesThisSample] = '\0';

        //logError("Event %s\n", eventName);

        // search for this eventName in the trie
        EventTrieInfo* info = (EventTrieInfo*)trie_lookup(eventTrie, eventName);
        if(info == NULL) {
            // doesn't exist, give it a TimestampBuffer
            info = (EventTrieInfo*)CALLOC(sizeof(EventTrieInfo), 1);
            strncpy(info->eventName, eventName, MAX_SIGNAL_NAME);
            trie_add(eventTrie, eventName, info);
        }

        // push this timestamp to the buffer
        bool success = pushTimestampToTimestampBuffer(&info->tsBuffer, groupTimestamps->timestamps[iSample]);
        if(!success) {
            logError("Issue building event fields\n");
            return;
        }
    }

    // now iterate over the eventName trie and add each field
    unsigned nEventNames = trie_count(eventTrie);
    mxArray* mxSignalNames = mxCreateCellMatrix(nEventNames, 1);

    unsigned iEvent = 0;
    unsigned fieldNum = 0;
    trieNode = trie_get_first(eventTrie);
    char fieldName[MAX_SIGNAL_NAME];
    while(trieNode != NULL) {
        EventTrieInfo* info = (EventTrieInfo*)trieNode->value;

        // build the groupName_eventName field name
        if(useGroupPrefix)
            snprintf(fieldName, MAX_SIGNAL_NAME, "%s_%s", groupName, info->eventName);
        else
            strncpy(fieldName, info->eventName, MAX_SIGNAL_NAME);

        // store the name of the field in the cell array
        mxSetCell(mxSignalNames, iEvent, mxCreateString(fieldName));

        // copy timestamps from buffer to double vector
        mxArray* mxTimestamps = mxCreateNumericMatrix(info->tsBuffer.nSamples, 1, mxDOUBLE_CLASS, mxREAL);

        // subtract off trial start time and convert to ms, rounding at ms
        double_t* buffer = (double_t*)mxGetData(mxTimestamps);
        for(unsigned i = 0; i < info->tsBuffer.nSamples; i++)
            buffer[i] = round((info->tsBuffer.timestamps[i] - timeTrialStart));

        // add event time list field to trial struct
        fieldNum = mxAddField(mxTrial, fieldName);
        mxSetFieldByNumber(mxTrial, 0, fieldNum, mxTimestamps);

        // get the next event in the trie
        trieNode = trie_get_next(trieNode);
        iEvent++;
    }

    // free the event Trie resources
    trie_flush(eventTrie, FREE);

    // add signal names to the meta array
    fieldNum = mxGetFieldNumber(mxGroupMeta, "signalNames");
    if(fieldNum == -1)
        fieldNum = mxAddField(mxGroupMeta, "signalNames");
    mxSetFieldByNumber(mxGroupMeta, groupMetaIndex, fieldNum, mxSignalNames);

}

//////////// FOR UDP MEX INTERACE /////////////////

mxArray* buildGroupsArrayForCurrentTrial(bool clearBuffers) {
    // if we're going to clear this trial's data, make sure we don't continue
    // to write into it anymore

    DataLoggerStatus* dlStatus = controlGetCurrentStatus();
    unsigned trialIdx;

    // TODO fix this, this isn't thread safe
    if(clearBuffers)
        trialIdx = controlManualSplitCurrentTrialMarkForWriting(dlStatus);
    else
        trialIdx = dlStatus->currentTrial;

    return buildGroupsArrayForTrial(dlStatus, trialIdx, clearBuffers);
}

mxArray* buildGroupsArrayForTrial(DataLoggerStatus *dlStatus, unsigned trialIdx, bool clearBuffers)
{
    DataLoggerStatusByTrial* trialStatus = dlStatus->byTrial + trialIdx;

    // gtrie for current trial
    GroupTrie* gtrie = dlStatus->gtrie;

    int nFieldsGroup = 7;
    const char* fieldNames[] = {"name", "type", "configHash", "version", "signalNames", "signals", "time"};
    mxArray *mxGroups, *mxSignals;

    unsigned nGroups = getGroupCount(gtrie);
    unsigned nGroupsUsed = 0;

    // create the outer groups array
    mxGroups = mxCreateStructMatrix(nGroups, 1, nFieldsGroup, fieldNames);

    if(trialStatus->utilized) {
        // ensure trial actually used
        timestamp_t trialStartTime = trialStatus->timestampStart;

        GroupTrie* groupNode = getFirstGroupNode(gtrie);
        SignalDataBuffer* psdb;
        for(unsigned iGroup = 0; iGroup < nGroups; iGroup++) {
            if(groupNode == NULL) break;
            GroupInfo* pg = (GroupInfo*)groupNode->value;
            unsigned nSamples = pg->tsBuffers[trialIdx].nSamples;

            if(pg->tsBuffers[trialIdx].nSamples > 0) {
                unsigned iGroupInArray = nGroupsUsed;

                // build an mxArray containing meta data about this group
                setGroupMetaFields((const GroupInfo*)pg, mxGroups, iGroupInArray);

                if(pg->type == GROUP_TYPE_ANALOG) {
                    // build an mxArray containing timestamps for this group
                    // false = don't use group field name prefix
                    addGroupTimestampsField(mxGroups, (const GroupInfo*)pg, trialIdx,
                        trialStartTime, false, iGroupInArray, nSamples);
                }

                // add in the signal fields
                mxSignals = mxCreateStructMatrix(1,1,0,NULL);
                if(pg->type != GROUP_TYPE_EVENT) {
					for(unsigned iSignal = 0; iSignal < pg->nSignals; iSignal++) {
						psdb = pg->signals[iSignal];
						if(psdb == NULL) continue;
						// add the signal data to mxSignals which is groups(iGroup).signals
						addSignalDataField(mxSignals, psdb, trialIdx, false, nSamples);

						// clear the timeseries buffer as these samples are no longer needed
						if(clearBuffers)
							clearSampleBuffer(psdb->buffers + trialIdx);
					}

                } else { // event group
                    // add the events directly to mxSignals, i.e. groups(iGroup.signals),
                    // without a group prefix
                    // add the meta field group.signalNames as groups(iGroup).signalNames
                    addEventGroupFields(mxSignals, mxGroups, pg, trialIdx,
                        trialStartTime, false, iGroupInArray);
                    if(clearBuffers) {
                    	for(unsigned iSignal = 0; iSignal < pg->nSignals; iSignal++) {
                    		psdb = pg->signals[iSignal];
                    		clearSampleBuffer(psdb->buffers + trialIdx);
                    	}
                    }
                }

                // add signals to groups(i).signals
                mxSetField(mxGroups, iGroupInArray, "signals", mxSignals);

                // clear the group's timestamp buffer
                if(clearBuffers)
                    clearTimestampBuffer(pg->tsBuffers + trialIdx);

                nGroupsUsed++;
            }

            // advance to the next group
            groupNode = getNextGroupNode(groupNode);
        }
    }
    // shrink the groups array in case some groups were unused
    if(nGroupsUsed < nGroups)
        mxSetM(mxGroups, nGroupsUsed);

    // mark this trial as written if we flushed the data
    if(clearBuffers) {
        controlMarkTrialWritten(dlStatus, trialIdx);
        //logInfo("marked trial %d as written\n", trialIdx);
    }

    return mxGroups;
}
