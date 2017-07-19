#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <asm-generic/errno-base.h>
#include "mat.h"

#include "utils.h"
#include "signal.h"
#include "signalLogger.h"

int PTHREAD_MUTEX_LOCK(pthread_mutex_t *mutex) {
    //logInfo("Attempting to lock mutex\n");

    tic();
    int val = 1;
    while(val != 0) {
        val = pthread_mutex_trylock(mutex);
        if(val == EINVAL) {
            while(true)
                logError("INVALID MUTEX!!!\n");
        }

        double t = tocCheck();
        if(t > 1) {
            logError("Hanging waiting for mutex!\n");
            //print_trace();
            tic();
        }
    }

    //int val = pthread_mutex_lock(mutex);
    //logInfo("Succeeded in locking mutex\n");
    return val;
}

int PTHREAD_MUTEX_UNLOCK(pthread_mutex_t *mutex) {
    //logInfo("Attempting to unlock mutex\n");
    int val = pthread_mutex_unlock(mutex);
    //logInfo("Succeeded in unlocking mutex\n");
    return val;
}

// DataLoggerStatus objects link the network thread to a specific GroupTrie
// which contains all of the GroupInfos which contain SignalDataBuffers
//
// When the protocol/protocolVersion/dataStore is changed on the sending end,
// we abandon all of these buffers because the fundamental trial data may change
// This happens in controlAdvanceToNextStatus() below.
// These are initialized in controlInitialize() below.
DataLoggerStatus* dlStatusCurrent;

// simple buffer for retired DataLoggerStatuses that the writer thread still
// needs to write to disk
#define STATUSES_RETIRED_NUM_BUFFER 2
DataLoggerStatus* dlStatusesRetired[STATUSES_RETIRED_NUM_BUFFER];
unsigned nStatusesRetired = 0;
pthread_mutex_t dlStatusesRetiredMutex = PTHREAD_MUTEX_INITIALIZER;

// these match the data type ids defined in signal.h
// note that "char" is actually uint8, but determines how we store it downstream
// i.e. char will be converted to a matlab string
const int nDataTypes = 10;
const char* dataTypeIdNames[] = {"double", "single", "int8", "uint8",
                                 "int16", "uint16", "int32", "uint32",
                                 "char", "logical"};

// these should match the defined constants in signal.h

// these should match BusSerialize.GroupType.m
const int nGroupTypes = 7;
const char * groupTypeNames[] = {"Unknown", "Control", "Param", "Analog", "Event", "Note"};

// these should match BusSerialize.SignalType.m
const int nSignalTypes = 10;
const char * signalTypeNames[] = {"Unspecified", "Timestamp", "TimestampOffset", "Pulse", "Param", "Analog", "EventName", "EventTag", "Spike", "SpikeWaveform"};

// lookup data type id name in dataTypeIdNames
const char * getDataTypeIdName(uint8_t dataTypeId)
{
    if(dataTypeId < 0 || dataTypeId >= nDataTypes)
        diep("Invalid data type Id");

    return dataTypeIdNames[dataTypeId];
}

// lookup group type by name in groupTypeNames[]
bool getGroupTypeName(uint8_t groupType, char* buffer)
{
    // group types are 1-indexed, see GROUP_TYPE_* in signal.h
    if(groupType < 1 || groupType > nGroupTypes) {
        logError("Invalid group type");
        return false;
    }

    strncpy(buffer, groupTypeNames[groupType], MAX_GROUP_TYPE_NAME);
    return true;
}

// lookup group type by name in groupTypeNames[]
bool getSignalTypeName(uint8_t signalType, char* buffer)
{
    // group types are 1-indexed, see GROUP_TYPE_* in signal.h
    if(signalType > nSignalTypes) {
        logError("Invalid signal type");
        return false;
    }

    strncpy(buffer, signalTypeNames[signalType], MAX_SIGNAL_TYPE_NAME);
    return true;
}

uint8_t getSizeOfDataTypeId(uint8_t dataTypeId)
{
    switch (dataTypeId) {
        case DTID_DOUBLE: // double
            return 8;

        case DTID_SINGLE: // single
        case DTID_INT32: // int32
        case DTID_UINT32: // uint32
            return 4;

        case DTID_INT8: // int8
        case DTID_UINT8: // uint8
        case DTID_CHAR: // char
        case DTID_LOGICAL: // logical
            return 1;

        case DTID_INT16: // int16
        case DTID_UINT16: // uint16
            return 2;

        default:
            logError("Data type id is %d unrecognized\n", dataTypeId);
            diep("Unknown data type Id");
    }

    return 0;
}

bool mallocSignalSampleData(SignalSample* psig)
{
    //printf("Allocating data for signal\n");
    psig->data = (uint8_t*)CALLOC(1, psig->dataBytes);
    if (psig->data == NULL)
        return false;
    else
        return true;
}

void freeSignalSampleData(SignalSample* psig)
{
    //printf("Freeing data for signal\n");
    if(psig->data != NULL)
        FREE(psig->data);
    psig->dataBytes = 0;
}

void printSignal(const SignalSample* psig)
{
    int nElements = 1;

    printf("\tSignal %10s [ts = %g, dims ", psig->name, psig->timestamp);

    printf("nDims = %d, ", psig->nDims);
    if (psig->nDims == 1) {
        printf("%dx%d", (int)psig->dims[0], 1);
        nElements = psig->dims[0];
    } else {
        for(int idim = 0; idim < psig->nDims; idim++) {
            nElements *= psig->dims[idim];
            printf("%4d", (int)psig->dims[idim]);
            if(idim < psig->nDims - 1)
                printf("x");
        }
    }
    printf(", type %6s ]", getDataTypeIdName(psig->dataTypeId));

    printf("\n");
}

void printGroupInfo(const GroupInfo* pg)
{
    char typeName[MAX_GROUP_TYPE_NAME];
    getGroupTypeName(pg->type, typeName);
    printf("Group : %10s [ type = %d, v = %d, nSignals = %d ]\n",
            pg->name, pg->type, pg->version, pg->nSignals);
}

/////// GROUP TRIE /////////

// group key is just the group name
void buildGroupKey(const GroupInfo *pg, char* key) {
    strncpy(key, pg->name, MAX_GROUP_NAME);
}

// return the group info matching pg on the GroupTrie
// or NULL if not found
GroupInfo* findGroupInfoInTrie(const GroupInfo* pg) {
    GroupTrie* gtrie = getCurrentGroupTrie();
    char key[GROUPKEYLENGTH];
    buildGroupKey(pg, key);

    // search for an existing signal data buffer on the trie
    GroupInfo* pgOnTrie = (GroupInfo*)trie_lookup(gtrie, key);

    return pgOnTrie;
}

GroupInfo* addGroupInfoToTrie(const GroupInfo*pg) {
    char key[GROUPKEYLENGTH];
    buildGroupKey(pg, key);
    GroupTrie* gtrie = getCurrentGroupTrie();

    // not found, calloc one
    GroupInfo* pgOnTrie = (GroupInfo*)CALLOC(sizeof(GroupInfo), 1);
    if(pgOnTrie == NULL) return NULL;

    // copy the group info into it
    memcpy(pgOnTrie, pg, sizeof(GroupInfo));

    // allocate SignalDataBuffers list for this group info
    pgOnTrie->signals = (SignalDataBuffer**)CALLOC(sizeof(SignalDataBuffer*), pg->nSignals);

    trie_add(gtrie, key, pgOnTrie);

    return pgOnTrie;
}

// free memory used by a group info object and all children
// frees the pg pointer as well!
void freeGroupInfo(GroupInfo* pg) {
    unsigned i;

    // free each signal
    if(pg->signals != NULL) {
        // pg->signals is SignalDataBuffer**, the array itself is allocated
        // in addition to each element
        for(i = 0; i < pg->nSignals; i++) {
            if(pg->signals[i] != NULL) {
                freeSignalDataBuffer(pg->signals[i]);
                FREE(pg->signals[i]);
            }
        }
        FREE(pg->signals);
        pg->signals = NULL;
    }

    // free timestamp buffers
    for(i = 0; i < BUFFER_NUM_TRIALS; i++) {
        freeTimestampBuffer(pg->tsBuffers + i);
    }

    // free the pointer itself
    FREE(pg);
}

GroupTrie* getCurrentGroupTrie() {
    DataLoggerStatus* dlStatus = controlGetCurrentStatus();
    return dlStatus->gtrie;
}

// flush the group info trie contents and everything within
// also free the pointer itself
void freeGroupInfoTrie(GroupTrie* gtrie) {
    // call the callback on each group info to free the associated memory
    trie_flush(gtrie, (void (*)(void*))freeGroupInfo);
}

// append a timestamped sample to the group info's internal list
// if signals contains signals with type SIGNAL_TYPE_TIMESTAMP or SIGNAL_TYPE_TIMESTAMPOFFSET,
// use these to adjust or otherwise replace the timestamps directly
// length of signals must match pg->nSignals
timestamp_t pushTimestampToGroupInfo(GroupInfo* pg, timestamp_t ts, const SignalSample * signals, int nSignals) {
    controlMarkCurrentTrialUtilized(ts); // essential for this trial to be written to disk
    TimestampBuffer* ptb = pg->tsBuffers + controlGetCurrentTrialIndex();

    // first, check whether the group has any signals with type SIGNALTYPE_TIMESTAMPS
    // with type DTID_UINT32

    int idxSignalTimestamp = -1;
    int idxSignalTimestampOffset = -1;
    unsigned nTimestamps;
    for(unsigned i = 0; i < nSignals; i++) {
        const SignalSample* ps = signals + i;

        if(ps->type == SIGNAL_TYPE_TIMESTAMP) {
        	if(ps->dataTypeId != DTID_UINT32)
        		logError("Signal with type TIMESTAMP must have data type uint32\n");
        	else
        		idxSignalTimestamp = i;
        }
        if(ps->type == SIGNAL_TYPE_TIMESTAMPOFFSET) {
        	if(ps->dataTypeId != DTID_SINGLE)
        		logError("Signal with type TIMESTAMPOFFSET must have data type single\n");
        	else
        		idxSignalTimestampOffset = i;
        }
    }

	// if we're overriding the group timestamp, meaning we may be carrying multiple samples
	if(idxSignalTimestamp >= 0)
		nTimestamps = signals[idxSignalTimestamp].dataBytes / getSizeOfDataTypeId(DTID_UINT32);
	else if(idxSignalTimestampOffset >= 0)
		nTimestamps = signals[idxSignalTimestampOffset].dataBytes / getSizeOfDataTypeId(DTID_SINGLE);
	else
		nTimestamps = 1;

	// loop over the timestamps and adjust each accordingly
	timestamp_t tsCorrected;
	for(unsigned iT = 0; iT < nTimestamps; iT++) {
		tsCorrected = ts;

		if(idxSignalTimestamp>=0)
			tsCorrected = (timestamp_t) (((uint32_t*)(signals[idxSignalTimestamp].data))[iT]);

		if(idxSignalTimestampOffset>=0)
			tsCorrected += (timestamp_t) (((single_t*)(signals[idxSignalTimestampOffset].data))[iT]);

		if(pg->type == GROUP_TYPE_PARAM) {
			// replace the existing timestamp, param's aren't buffered
			replaceTimestampBufferData(ptb, tsCorrected);
		} else {
			// push the new sample, the timeseries will allocate new memory as needed
			pushTimestampToTimestampBuffer(ptb, tsCorrected);
		}
	}

	return tsCorrected;
}

// iterating over the signal trie
GroupTrie* getFirstGroupNode(GroupTrie* gtrie) {
    return trie_get_first(gtrie);
}

GroupTrie* getNextGroupNode(GroupTrie* node) {
    return trie_get_next(node);
}

unsigned getGroupCount(GroupTrie* gtrie) {
    return trie_count(gtrie);
}

unsigned getSignalCountFromGroup(GroupInfo* pg) {
    return pg->nSignals;
}

unsigned getGroupTotalSignalCount(GroupTrie* gtrie) {
    return trie_accumulate(gtrie, (unsigned (*)(void*))getSignalCountFromGroup);
}

/////// SIGNAL DATA BUFFERS /////////

// given the signal metadata on SignalSample ps, find a signal data buffer for
// this signal on the signal trie strie. If not found, create a signal data buffer for it.
// return the signal data buffer pointer
bool checkSignalDataBufferMatchesSample(const SignalDataBuffer* psdb, const SignalSample *ps) {
    if(strncmp(ps->name, psdb->name, MAX_SIGNAL_NAME) != 0) return false;
    if(ps->dataTypeId != psdb->dataTypeId) return false;
    if(ps->nDims != psdb->nDims) return false;
    if(ps->pGroupInfo != psdb->pGroupInfo) return false;

    return true;
}

// build a new SignalDataBuffer and copy metadata from a SignalSample
SignalDataBuffer* buildSignalDataBufferFromSample(const SignalSample *ps) {
    SignalDataBuffer* psdb = (SignalDataBuffer*)CALLOC(sizeof(SignalDataBuffer), 1);

    psdb->isVariable = ps->isVariable;
    psdb->concatLastDim = ps->concatLastDim;
    psdb->concatDimension = ps->concatDimension;
    psdb->type = ps->type;

    // and copy over the metadata fields
    strncpy(psdb->name, ps->name, MAX_SIGNAL_NAME);
    strncpy(psdb->units, ps->units, MAX_SIGNAL_UNITS);

    psdb->dataTypeId = ps->dataTypeId;
    psdb->nDims = ps->nDims;
    memcpy(psdb->dims, ps->dims, psdb->nDims*sizeof(*psdb->dims));

    psdb->pGroupInfo = ps->pGroupInfo;

    return psdb;
}

// given a data sample from a particular signal, either find this signal data buffer
// in the signal trie, or create one for it. then add the signal sample data to
// data buffer for the current trial
bool pushSignalSampleToSignalDataBuffer(SignalDataBuffer* psdb, const SignalSample* ps) {
    bool success;

    // get the timeseries buffer we're currently writing into
    SampleBuffer* ptb = psdb->buffers + controlGetCurrentTrialIndex();

    unsigned groupType = psdb->pGroupInfo->type;
    unsigned signalType = psdb->type;

    if (ptb->nSamples == 0) {
        // first sample, update dimensions of the sample
        psdb->nDims = ps->nDims;
        memcpy(psdb->dims, ps->dims, psdb->nDims*sizeof(*psdb->dims));

        // clear register signal dimensions changing size
        memset(psdb->dimChangesSize, 0, MAX_SIGNAL_NDIMS*sizeof(bool)); 

    } else {
        // check whether any dimension has changed size
        for(unsigned iDim = 0; iDim < psdb->nDims; iDim++) {
            if(psdb->dims[iDim] != ps->dims[iDim])
                psdb->dimChangesSize[iDim] = true;
        }
    }

    if(groupType == GROUP_TYPE_PARAM || signalType == SIGNAL_TYPE_PARAM) {
        // replace the existing value, param's aren't buffered
        success = replaceSampleBufferData(ptb, ps->dataBytes, ps->data);
    } else {
        // push the new sample, the timeseries will allocate new memory as needed
        success = pushSampleToSampleBuffer(ptb, ps->dataBytes, ps->data);
    }
    if(!success) {
        logError("Could not allocate memory for signal buffer %s\n", ps->name);
        return false;
    }

    return true;
}

// free memory used by a signal data buffer object but not the pointer itself
void freeSignalDataBuffer(SignalDataBuffer *psdb) {
    for(unsigned i = 0; i < BUFFER_NUM_TRIALS; i++) {
        freeSampleBuffer(psdb->buffers +i);
    }
}

//////// Timestamp Buffer Utils ////////

// ensure that ptb can acccommodate nSamples of data, at bytesPerSample bytes each
// returns true if successful, false if couldn't allocate enough memory
bool ensureTimestampBufferCapacity(TimestampBuffer *ptb, uint32_t nSamples) {
    uint32_t samplesToAllocate;

    if(ptb->timestamps == NULL) {
        // not allocated yet, CALLOC from scratch
        // allocate bytesEachSample array to be same length as timestamps (except uint32)
        ptb->timestamps = (timestamp_t*)CALLOC(sizeof(timestamp_t), nSamples);
        if(ptb->timestamps == NULL) {
            ptb->samplesAllocated = 0;
            return false;
        }

        ptb->samplesAllocated = nSamples;
        ptb->nSamples = 0;

    } else {
        // rellocate a larger space for new data
        if(ptb->samplesAllocated < nSamples) {
            // allocate more data, either double the allocated space or the needed bytes, whichever is larger
            if(ptb->samplesAllocated*2 > nSamples)
                // double capacity
                samplesToAllocate = ptb->samplesAllocated * 2;
            else
                // use requested capacity
                samplesToAllocate = nSamples;

            ptb->timestamps = (timestamp_t*)realloc(ptb->timestamps, sizeof(timestamp_t) * samplesToAllocate);
            if(ptb->timestamps == NULL) {
                ptb->samplesAllocated = 0;
                return false;
            }
            ptb->samplesAllocated = samplesToAllocate;
        }
    }

    return true;
}

bool ensureTimestampBufferAdditionalCapacity(TimestampBuffer *ptb, uint32_t nSamplesAdditional) {
    return ensureTimestampBufferCapacity(ptb, ptb->nSamples + nSamplesAdditional);
}

// clear the buffer without freeing memory
void clearTimestampBuffer(TimestampBuffer* ptb) {
    memset(ptb->timestamps, 0, ptb->samplesAllocated*sizeof(timestamp_t));
    ptb->nSamples = 0;
}

// free the internal memory used by a TimestampBuffer, but do not FREE the pointer itself
void freeTimestampBuffer(TimestampBuffer* ptb) {
    if(ptb->timestamps != NULL)
        FREE(ptb->timestamps);
    ptb->samplesAllocated = 0;
    ptb->nSamples = 0;
}

bool replaceTimestampBufferData(TimestampBuffer* ptb, timestamp_t timestamp) {
    clearTimestampBuffer(ptb);
    return pushTimestampToTimestampBuffer(ptb, timestamp);
}

bool pushTimestampToTimestampBuffer(TimestampBuffer* ptb, timestamp_t timestamp) {
    // allocate space for the additional samples
    bool success = ensureTimestampBufferAdditionalCapacity(ptb, 1);
    if(!success) return false;

    // store the new timestamp
    ptb->timestamps[ptb->nSamples] = timestamp;

    // increment the used counter
    ptb->nSamples++;

    return true;
}

//////// Sample Buffer Utils ////////


// ensure that ptb can acccommodate nSamples of data, at bytesPerSample bytes each
// returns true if successful, false if couldn't allocate enough memory
bool ensureSampleBufferCapacity(SampleBuffer *ptb, uint32_t nSamples, uint32_t dataBytesNeeded) {
    uint32_t dataBytesToAllocate, samplesToAllocate;

    if(ptb->data == NULL) {
        // not allocated yet, CALLOC from scratch
        ptb->data = (uint8_t*)CALLOC(sizeof(uint8_t), dataBytesNeeded);
        if(ptb->data == NULL) {
            ptb->dataAllocated = 0;
            return false;
        }
        ptb->dataAllocated = dataBytesNeeded;

        // allocate bytesEachSample array to be same length as timestamps (except uint32)
        ptb->bytesEachSample = (uint32_t*)CALLOC(sizeof(uint32_t), nSamples);
        if(ptb->bytesEachSample == NULL) {
            ptb->samplesAllocated = 0;
            return false;
        }

        ptb->samplesAllocated = nSamples;
        ptb->nSamples = 0;
        ptb->nDataBytes = 0;

    } else {
        // rellocate a larger space for new data
        if(ptb->dataAllocated < dataBytesNeeded) {
            // allocate more data, either double the allocated space or the needed bytes, whichever is larger
            if(ptb->dataAllocated*2 > dataBytesNeeded)
                dataBytesToAllocate = ptb->dataAllocated * 2;
            else
                dataBytesToAllocate = dataBytesNeeded;

            ptb->data = (uint8_t*)realloc(ptb->data, dataBytesToAllocate);
            if(ptb->data == NULL) {
                ptb->dataAllocated = 0;
                return false;
            }
            ptb->dataAllocated = dataBytesToAllocate;
        }

        // rellocate a larger space for bytes per sample
        if(ptb->samplesAllocated < nSamples) {
            // allocate more timestamps, either double the allocated space or the needed bytes, whichever is larger
            if(ptb->samplesAllocated*2 > nSamples)
                samplesToAllocate = ptb->samplesAllocated * 2;
            else
                samplesToAllocate = nSamples;

            ptb->bytesEachSample = (uint32_t*)realloc(ptb->bytesEachSample, sizeof(uint32_t)*samplesToAllocate);
            if(ptb->bytesEachSample == NULL) {
                ptb->samplesAllocated = 0;
                return false;
            }

            ptb->samplesAllocated = samplesToAllocate;
        }
    }

    return true;
}

bool ensureSampleBufferAdditionalCapacity(SampleBuffer *ptb, uint32_t nSamplesAdditional, uint32_t nDataBytesAdditional) {
    return ensureSampleBufferCapacity(ptb, ptb->nSamples + nSamplesAdditional, ptb->nDataBytes + nDataBytesAdditional);
}

// clear the buffer without freeing memory
void clearSampleBuffer(SampleBuffer* ptb) {
    memset(ptb->data, 0, ptb->dataAllocated);
    memset(ptb->bytesEachSample, 0, ptb->samplesAllocated*sizeof(uint32_t));
    ptb->nSamples = 0;
    ptb->nDataBytes = 0;
    ptb->samplesDifferentSizes = false;
}

// free the internal memory used by a SampleBuffer
void freeSampleBuffer(SampleBuffer* ptb) {
    if(ptb->data != NULL)
        FREE(ptb->data);

    if(ptb->bytesEachSample != NULL)
        FREE(ptb->bytesEachSample);

    ptb->dataAllocated = 0;
    ptb->samplesAllocated = 0;
    ptb->nSamples = 0;
    ptb->nDataBytes = 0;
    ptb->samplesDifferentSizes = false;
}

bool pushSampleToSampleBuffer(SampleBuffer* ptb, uint32_t nDataBytes, const uint8_t* data) {
    // allocate space for the additional samples
    bool success = ensureSampleBufferAdditionalCapacity(ptb, 1, nDataBytes);
    if(!success) return false;

    // store the new data
    memcpy(ptb->data + ptb->nDataBytes, data, nDataBytes);

    // and the size of this sample
    ptb->bytesEachSample[ptb->nSamples] = nDataBytes;

    // check whether samples remained same size as previous
    if(ptb->nSamples > 1 && ptb->bytesEachSample[ptb->nSamples] != ptb->bytesEachSample[ptb->nSamples-1])
        ptb->samplesDifferentSizes = true;

    // increment the used counters
    ptb->nSamples++;
    ptb->nDataBytes += nDataBytes;

    return true;
}

// dump all existing values and add the new ones
bool replaceSampleBufferData(SampleBuffer* ptb, uint32_t nDataBytes, const uint8_t* data) {
    clearSampleBuffer(ptb);
    return pushSampleToSampleBuffer(ptb, nDataBytes, data);
}

////// DATA LOGGER STATUS //////

bool processControlSignalSamples(unsigned nSamples, const SignalSample* samples) {
    // receive a list of control signal samples and process them
    //
    // if any of these would cause a change to the following fields of DataLoggerStatus:
    //    protocol
    //
    // then we will abandon the current status and move on to a new one. The old status will
    // be pushed to a buffer of "backlog" statuses, which allows us the writer thread
    // to write them to disk and flush them to memory
    //
    // changing other fields do not cause a DataLoggerStatus advance, but simply
    // overwrite the current value in DataLoggerStatusByTrial, which is on a ring buffer inside
    // the current dataLoggerStatus to begin with

    bool alreadyNewStatus = false;
    DataLoggerStatus* dlStatus = controlGetCurrentStatus();
    //DataLoggerStatusByTrial* trialStatus;

    for(unsigned i = 0; i < nSamples; i++) {
        const SignalSample* ps = samples + i;

        if(strncasecmp(ps->name, "protocol", MAX_SIGNAL_NAME) == 0) {
            if(strncmp(dlStatus->protocol, (char*)ps->data, MAX_STRING) != 0) {
                // protocol is changing, advance status if we haven't advanced already
                // and this is overriding a non-default previously specified value
                if(!alreadyNewStatus && dlStatus->protocolSpecified) {
                    alreadyNewStatus = true;
                    dlStatus = controlAdvanceToNewStatus();
                }
                strncpy(dlStatus->protocol, (char*)ps->data, MAX_STRING);
                dlStatus->protocolSpecified = true;
                logInfo("Updating Protocol: %s\n", dlStatus->protocol);
            }

        } else if(strncasecmp(ps->name, "protocolVersion", MAX_SIGNAL_NAME) == 0) {
            if(dlStatus->protocolVersion != ((uint32_t*)ps->data)[0]) {
                // protocol version is changing, advance status if we haven't advanced already
                if(!alreadyNewStatus && dlStatus->protocolVersionSpecified) {
                    alreadyNewStatus = true;
                    dlStatus = controlAdvanceToNewStatus();
                }
                dlStatus->protocolVersion = ((uint32_t*)ps->data)[0];
                dlStatus->protocolVersionSpecified = true;
                logInfo("Updating Protocol Version: %d\n", dlStatus->protocolVersion);
            }

        } else if(strncasecmp(ps->name, "subject", MAX_SIGNAL_NAME) == 0) {
            if(strncmp(dlStatus->subject, (char*)ps->data, MAX_STRING) != 0) {
                // subject is changing, advance status if we haven't advanced already
                if(!alreadyNewStatus && dlStatus->subjectSpecified) {
                    alreadyNewStatus = true;
                    dlStatus = controlAdvanceToNewStatus();
                }
                strncpy(dlStatus->subject, (char*)ps->data, MAX_STRING);
                dlStatus->subjectSpecified = true;
                logInfo("Updating Subject: %s\n", dlStatus->subject);
            }

        } else if(strncasecmp(ps->name, "dataStore", MAX_SIGNAL_NAME) == 0) {
            if(strncmp(dlStatus->dataStore, (char*)ps->data, MAX_STRING) != 0) {
                // dataStore is changing, advance status if we haven't advanced already
                if(!alreadyNewStatus && dlStatus->dataStoreSpecified) {
                    alreadyNewStatus = true;
                    dlStatus = controlAdvanceToNewStatus();
                }
                strncpy(dlStatus->dataStore, (char*)ps->data, MAX_STRING);
                dlStatus->dataStoreSpecified = true;
                logInfo("Updating Data Store: %s\n", dlStatus->dataStore);
            }

        } else if(strncasecmp(ps->name, "saveTag", MAX_SIGNAL_NAME) == 0) {
            // save tag # changing
            if(dlStatus->saveTag != ((uint32_t*)ps->data)[0]) {
                // saveTag is changing, advance status if we haven't advanced already
                if(!alreadyNewStatus && dlStatus->saveTagSpecified) {
                    alreadyNewStatus = true;
                    dlStatus = controlAdvanceToNewStatus();
                }
                dlStatus->saveTag = (((uint32_t*)ps->data)[0]);
                dlStatus->saveTagSpecified = true;
                logInfo("Updating SaveTag: %d\n", dlStatus->saveTag);
            }

        } else if(strncasecmp(ps->name, "nextTrial", MAX_SIGNAL_NAME) == 0) {
            // advancing to next trial with provided trial id, false means actually a new trial
            // this will also triggering
            controlAdvanceToNextTrial(((uint32_t*)ps->data)[0], false);
        }
    }

    return true;
}

// be sure to call this only once!
void controlInitialize(bool pendingNextTrial) {
    dlStatusCurrent = (DataLoggerStatus*)CALLOC(sizeof(DataLoggerStatus), 1);
    if(dlStatusCurrent == NULL) diep("No memory to initialize data logger status");
    controlInitializeStatus(dlStatusCurrent, NULL);

    memset(dlStatusesRetired, 0, sizeof(DataLoggerStatus*) * STATUSES_RETIRED_NUM_BUFFER);
    nStatusesRetired = 0;

    // controlInitializeStatus sets pendingNextTrial to true
    // the pendingNextTrial flag allows us to bypass this when we're less concerned with
    // logging analog signals and just relaying parameters
    if(pendingNextTrial)
        logInfo("Status: Waiting for nextTrial control signal...\n");
    else
        dlStatusCurrent->pendingNextTrial = false;
}

void controlTerminate() {
    DataLoggerStatus* dlStatus;
    while((dlStatus = controlPopRetiredStatus()) != NULL)
        freeDataLoggerStatus(dlStatus);

    if(dlStatusCurrent != NULL) {
        freeDataLoggerStatus(dlStatusCurrent);
        dlStatusCurrent = NULL;
    }
}

// initialize dlStatus, optionally copying values from prevStatus if not NULL
void controlInitializeStatus(DataLoggerStatus* dlStatus, const DataLoggerStatus* prevStatus) {
    memset(dlStatus, 0, sizeof(DataLoggerStatus));

    // initialize the dlStatus mutex as recursive
    pthread_mutexattr_init(&dlStatus->mutexAttr);
    pthread_mutexattr_settype(&dlStatus->mutexAttr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&dlStatus->mutex, &dlStatus->mutexAttr);

    if(prevStatus == NULL) {
        strcpy(dlStatus->subject, "DefaultSubject");
        strcpy(dlStatus->dataStore, "DefaultDataStore");
        strcpy(dlStatus->protocol, "DefaultProtocol");
        dlStatus->protocolVersion = 0;
        dlStatus->saveTag = 0;
    } else {
        // copy over everything from prevStatus
        strcpy(dlStatus->subject, prevStatus->subject);
        strcpy(dlStatus->dataStore, prevStatus->dataStore);
        strcpy(dlStatus->protocol, prevStatus->protocol);
        dlStatus->protocolVersion = prevStatus->protocolVersion;
        dlStatus->saveTag = prevStatus->saveTag;

        dlStatus->subjectSpecified = prevStatus->subjectSpecified;
        dlStatus->protocolSpecified = prevStatus->protocolSpecified;
        dlStatus->protocolVersionSpecified = prevStatus->protocolVersionSpecified;
        dlStatus->dataStoreSpecified = prevStatus->dataStoreSpecified;
        dlStatus->saveTagSpecified = prevStatus->saveTagSpecified;
    }

    dlStatus->retired = false;

    // initialize in pendingNextTrial state so that we don't save partial trial information
    dlStatus->pendingNextTrial = true;

    // initialize all of the byTrial statuses within
    memset(dlStatus->byTrial, 0, BUFFER_NUM_TRIALS*sizeof(DataLoggerStatusByTrial));

    dlStatus->gtrie = trie_create();

    dlStatus->currentTrial = 0;
    dlStatus->byTrial[dlStatus->currentTrial].activeLogging = true;
    dlStatus->byTrial[dlStatus->currentTrial].autoTrialId = true;
}

// free dlStatus and all of it's contents
void freeDataLoggerStatus(DataLoggerStatus* dlStatus) {
    if(dlStatus == NULL) return;

    pthread_mutex_destroy(&dlStatus->mutex);
    if(dlStatus->gtrie != NULL)
        freeGroupInfoTrie(dlStatus->gtrie);
    FREE(dlStatus);
}

DataLoggerStatus* controlGetCurrentStatus() {
    return dlStatusCurrent;
}

unsigned controlGetCurrentTrialIndex() {
    DataLoggerStatus *dlStatus = controlGetCurrentStatus();
    return dlStatus->currentTrial;
}

// returns true if data logger is waiting for next trial command
// before writing additional trials
bool controlGetWaitingForNextTrial() {
    DataLoggerStatus *dlStatus = controlGetCurrentStatus();
    return dlStatus->pendingNextTrial;
}

// clear all the data associated with a particular trial without deallocating buffers
// DOES NOT lock mutex for that data logger status
void controlClearTrialData(DataLoggerStatus* dlStatus, unsigned trialIdx) {
    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);

    GroupTrie *groupNode = getFirstGroupNode(dlStatus->gtrie);

    while(groupNode != NULL) {
        GroupInfo *pg = (GroupInfo*)groupNode->value;
        // clear each signal's buffer for that trial
        for(unsigned i = 0; i < pg->nSignals; i++) {
            clearSampleBuffer(pg->signals[i]->buffers + trialIdx);
        }

        // clear timestamp buffer for that trial
        clearTimestampBuffer(pg->tsBuffers + trialIdx);

        // get next group
        groupNode = getNextGroupNode(groupNode);
    }

    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);
}

// lock the mutex for this dlStatus, and then find the next non-utilized trial
// in the array of trials
// returns the trialIdx if there is one or -1 if no trials may be written
int controlGetNextCompleteTrialToWrite(DataLoggerStatus* dlStatus) {
    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);

    // find the next trial slot in the buffer that isn't being actively logged
    // this must find something since only one trial should be actively writing
    // at any point in time
    bool found = false;
    unsigned newTrial;
    for(unsigned i = 0; i < BUFFER_NUM_TRIALS; i++) {
        newTrial = (dlStatus->currentTrial + i + 1) % BUFFER_NUM_TRIALS;
        if(!dlStatus->byTrial[newTrial].activeLogging &&
           dlStatus->byTrial[newTrial].completed &&
           dlStatus->byTrial[newTrial].utilized) {
            found = true;
            break;
        }
    }

    if(found)
        dlStatus->byTrial[newTrial].activeWriting = true;

    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);

    if(found)
        return newTrial;
    else
        return -1;
}

void controlMarkTrialWritten(DataLoggerStatus* dlStatus, unsigned trialIdx) {
    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);
    dlStatus->byTrial[trialIdx].activeWriting = false;
    dlStatus->byTrial[trialIdx].utilized = false;
    dlStatus->byTrial[trialIdx].completed = false;
    dlStatus->byTrial[trialIdx].activeLogging = false;
    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);
}

// mark this trial as utilized until at least this timestamp
void controlMarkCurrentTrialUtilized(timestamp_t ts) {
    DataLoggerStatus *dlStatus = controlGetCurrentStatus();
    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);

    timestamp_t currentWallclock = getCurrentWallclock();

    DataLoggerStatusByTrial* dlTrial = dlStatus->byTrial + dlStatus->currentTrial;
    if(!dlTrial->utilized) {
        dlTrial->utilized = true;

        // log current timestamp as wallclock start
        dlTrial->wallclockStart = currentWallclock;
        dlTrial->timestampStart = ts;

        // auto generate trial id from wallclock start time HHMMSSsss?
        if(dlTrial->autoTrialId) {
            unsigned msec;
            struct tm timeInfo;
            convertWallclockToLocalTime(getCurrentWallclock(), &timeInfo, &msec);
            dlTrial->trialId = (timeInfo.tm_hour) * 10000000 + (timeInfo.tm_min) * 100000
                + (timeInfo.tm_sec) * 1000 + msec;
        }
    }

    // extend timestamp of utilization to include present time
    if(dlTrial->timestampEnd == 0 || dlTrial->timestampEnd < ts)
        dlTrial->timestampEnd = ts;
    dlTrial->wallclockEnd = currentWallclock;

    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);
}


// manually advance the trial buffer we use without changing the trialId
// used to prevent infinite accumulation of data when not sending trial advance cues
void controlManualSplitCurrentTrial() {
   //logInfo("Manually splitting current trial\n");
    controlAdvanceToNextTrial(0, true);
}

// manually advance the trial buffer, marking what was just the current trial
// for writing. Return the trialIdx to be written or -1 if there are no trials to
// be written
unsigned controlManualSplitCurrentTrialMarkForWriting(DataLoggerStatus *dlStatus) {
    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);

    //logInfo("Manual split current trial %d\n", dlStatus->currentTrial);
    unsigned trialToWrite = controlAdvanceToNextTrial(0, true);
    //logInfo("Split current trial, now %d, writing %d\n", dlStatus->currentTrial, trialToWrite);

    if(trialToWrite != -1)
        dlStatus->byTrial[trialToWrite].activeWriting = true;
    else
        logError("could not find trial to write\n");

    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);

    return trialToWrite;
}

void controlManualSplitCurrentTrialIfOlderThan(timestamp_t nSeconds) {
    DataLoggerStatus* dlStatus = controlGetCurrentStatus();

    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);

    timestamp_t wallclockThresh = getCurrentWallclock() - nSeconds;
    unsigned currentTrial = dlStatus->currentTrial;
    if(dlStatus->byTrial[currentTrial].activeLogging &&
       dlStatus->byTrial[currentTrial].utilized &&
       dlStatus->byTrial[currentTrial].wallclockStart <= wallclockThresh)
        controlAdvanceToNextTrial(0, true);

    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);
}

// flush data in trials which do not contain any data that is less than nSeconds old
// EXCLUDING THE CURRENT TRIAL
void controlFlushTrialsOlderThan(timestamp_t nSeconds) {
    DataLoggerStatus* dlStatus = controlGetCurrentStatus();

    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);
    timestamp_t wallclockThresh = getCurrentWallclock() - nSeconds;

    // find the next trial slot in the buffer that isn't being actively logged
    // this must find something since only one trial should be actively writing
    // at any point in time
    for(unsigned i = 0; i < BUFFER_NUM_TRIALS; i++) {
        if(!dlStatus->byTrial[i].activeWriting &&
           !dlStatus->byTrial[i].activeLogging &&
           dlStatus->byTrial[i].utilized &&
           dlStatus->byTrial[i].wallclockEnd <= wallclockThresh) {
            // this trial is old, clear the data
            logInfo("Flushing old trial data for buffered trial %d\n", i);
            controlClearTrialData(dlStatus, i);
            dlStatus->byTrial[i].utilized = false;
            dlStatus->byTrial[i].activeWriting = false;
            dlStatus->byTrial[i].activeLogging= false;
            dlStatus->byTrial[i].completed = false;
            dlStatus->byTrial[i].wallclockEnd = 0;
        }
    }

    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);
}

/////////// DATA LOGGER STATUS MANAGEMENT //////////////

void controlMarkTrialComplete(DataLoggerStatus* dlStatus, unsigned trialIdx) {
    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);

    dlStatus->byTrial[trialIdx].completed = true;
    dlStatus->byTrial[trialIdx].activeLogging = false;

    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);
}

// something in the status is about to change and we need to abandon the current
// one, mark it as retired, and move to a new one
DataLoggerStatus* controlAdvanceToNewStatus() {
    DataLoggerStatus* dlStatusPrev = controlGetCurrentStatus();
    DataLoggerStatus* dlStatusNew = (DataLoggerStatus*)CALLOC(sizeof(DataLoggerStatus), 1);
    if(dlStatusNew == NULL) diep("No memory for new data logger status");

    // setup the new status and get going immediately
    logInfo("Advancing to new DataLoggerStatus, waiting for nextTrial command\n");
    controlInitializeStatus(dlStatusNew, dlStatusPrev);

    dlStatusCurrent = dlStatusNew;

    // then push the old status to the retired list
    controlPushRetiredStatus(dlStatusPrev);

    // mark the trial we were just using as finished
    controlMarkTrialComplete(dlStatusPrev, dlStatusPrev->currentTrial);

    return dlStatusNew;
}

void controlPushRetiredStatus(DataLoggerStatus* dlStatus) {
    if(nStatusesRetired == STATUSES_RETIRED_NUM_BUFFER) diep("Ran out of room in retired status buffer");

    PTHREAD_MUTEX_LOCK(&dlStatusesRetiredMutex);

    dlStatus->retired = true;
    dlStatusesRetired[nStatusesRetired++] = dlStatus;

    PTHREAD_MUTEX_UNLOCK(&dlStatusesRetiredMutex);
}

DataLoggerStatus* controlPopRetiredStatus() {
    if(nStatusesRetired == 0)
        return NULL;
    else {
        PTHREAD_MUTEX_LOCK(&dlStatusesRetiredMutex);

        // technically it's a LIFO rather than FIFO buffer, but it doesn't matter really
        // as long as no data gets lost
        DataLoggerStatus* ret = dlStatusesRetired[nStatusesRetired-1];
        dlStatusesRetired[nStatusesRetired-1] = NULL;
        nStatusesRetired--;

        PTHREAD_MUTEX_UNLOCK(&dlStatusesRetiredMutex);
        return ret;
    }
}

void controlFlushRetiredStatuses() {
    DataLoggerStatus *dlStatus;
    while((dlStatus = controlPopRetiredStatus()) != NULL)
        freeDataLoggerStatus(dlStatus);
}

// advance to the next trial within the active DataLoggerStatus
// begin writing immediately
// return old trial idx
unsigned controlAdvanceToNextTrial(uint32_t trialId, bool continuingSameTrial) {
	//printf("Advancing to new trial %d\n", trialId);
	DataLoggerStatus* dlStatus = controlGetCurrentStatus();
    PTHREAD_MUTEX_LOCK(&dlStatus->mutex);

    unsigned lastTrial, newTrial, trialPortion;
    lastTrial = dlStatus->currentTrial;

    // find the next trial slot in the buffer that isn't being actively written
    // this must find something since only one trial should be actively writing
    // at any point in time
    for(unsigned i = 0; i < BUFFER_NUM_TRIALS - 1; i++) {
        newTrial = (lastTrial + i + 1) % BUFFER_NUM_TRIALS;
        if(!dlStatus->byTrial[newTrial].activeWriting)
            break;
    }

    //logInfo("Advancing from trial %d to %d\n", lastTrial, newTrial);

    bool autoTrialId = false;
    if(trialId == 0 && !continuingSameTrial) {
        autoTrialId = true;
    }

    if(continuingSameTrial) {
        trialId = dlStatus->byTrial[lastTrial].trialId;
        trialPortion = dlStatus->byTrial[lastTrial].trialPortion + 1;
    } else {
        trialPortion = 0;
    }

    if(dlStatus->byTrial[newTrial].utilized) {
        //logError("Error: overwriting unwritten trial with id=%d\n", dlStatus->byTrial[newTrial].trialId);
    }

    // just to be sure any old data is gone, probably only necessary within the above if block
    controlClearTrialData(dlStatus, newTrial);

    // set new trial metadata
    dlStatus->byTrial[newTrial].autoTrialId = autoTrialId;
    dlStatus->byTrial[newTrial].trialId = trialId;
    dlStatus->byTrial[newTrial].trialPortion = trialPortion;

    // adjust the status flags
    dlStatus->byTrial[newTrial].activeLogging = true;
    dlStatus->byTrial[newTrial].completed = false;
    dlStatus->byTrial[newTrial].utilized = false;

    dlStatus->byTrial[lastTrial].completed = true;
    dlStatus->byTrial[lastTrial].activeLogging = false;

    dlStatus->currentTrial = newTrial;

    if(dlStatus->pendingNextTrial)
        logInfo("Status: nextTrial control signal received. Now logging received signals.\n");

    // mark that we're now ready to write
    dlStatus->pendingNextTrial = false;

    PTHREAD_MUTEX_UNLOCK(&dlStatus->mutex);

/*
    if(autoTrialId)
        logInfo("Advancing to new trial, trialId = <automatic by time>\n");
    else
        logInfo("Advancing to new trial, trialId = %d\n", trialId);
*/

    return lastTrial;
}

