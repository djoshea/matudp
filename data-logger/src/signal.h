#ifndef SIGNAL_H_INCLUDE
#define SIGNAL_H_INCLUDE

#include <stdbool.h>
#include <inttypes.h>
#include <stddef.h>
#include <pthread.h>
#include "trie.h"

///////////// MAXIMUM SIZES FOR PREALLOCATION /////////////

/* Signal maxima */
#define MAX_SIGNAL_NAME 300
#define MAX_SIGNAL_UNITS 300
#define MAX_SIGNAL_SIZE 10000  // max size along any dimension
#define MAX_SIGNAL_NDIMS 10
#define MAX_SIGNAL_TYPE_NAME 20

/* Group maxima */
#define MAX_GROUP_NAME 200
#define MAX_GROUP_TYPE_NAME 20
#define MAX_GROUP_META 200
#define MAX_GROUP_SIGNALS 500

/* Data store maxima */
#define MAX_STRING 300
#define MAX_STORE_NAME MAX_STRING

///////////// GROUP TYPE DEFINITIONS /////////////

// these aren't currently used, but if you change them,
// check getGroupTypeName()
#define GROUP_TYPE_CONTROL 1
#define GROUP_TYPE_PARAM 2
#define GROUP_TYPE_ANALOG 3
#define GROUP_TYPE_EVENT 4
#define GROUP_TYPE_SPIKE 5
#define GROUP_TYPE_FIELD 6

///////////// SIGNAL TYPE DEFINITIONS /////////////

// see addGroupTimestampsField to see how 1 and 2 are used
#define SIGNAL_TYPE_NORMAL 0
#define SIGNAL_TYPE_TIMESTAMP 1
#define SIGNAL_TYPE_TIMESTAMPOFFSET 2
#define SIGNAL_TYPE_PULSE 3
#define SIGNAL_TYPE_PARAM 4
#define SIGNAL_TYPE_ANALOG 5
#define SIGNAL_TYPE_EVENTNAME 6
#define SIGNAL_TYPE_EVENTTAG 7
#define SIGNAL_TYPE_SPIKE 8
#define SIGNAL_TYPE_SPIKEWAVEFORM 9

///////////// DATA TYPE ID DEFINITIONS /////////////
#define DTID_DOUBLE 0
#define DTID_SINGLE 1
#define DTID_INT8   2
#define DTID_UINT8  3
#define DTID_INT16  4
#define DTID_UINT16 5
#define DTID_INT32  6
#define DTID_UINT32 7
#define DTID_CHAR   8
#define DTID_LOGICAL 9

///////////// DATA TYPES DECLARATIONS /////////////

typedef float single_t;
typedef double double_t;

///////////// UINT8_T BUFFER UTILS ///////

// these macros help with the process of pulling bytes off of a uint8_t buffer
// [bufPtr], typecasting it as [type], and storing it in [assignTo]. The bufPtr
// is automatically advanced by the correct number of bytes. assignTo must be of
// type [type], not a pointer.
#define STORE_TYPE(type, bufPtr, assignTo) \
    memcpy(&assignTo, bufPtr, sizeof(type)); bufPtr += sizeof(type)

#define STORE_CHAR(bufPtr,   assignTo) STORE_TYPE(char,     bufPtr, assignTo)
#define STORE_INT8(bufPtr,   assignTo) STORE_TYPE(int8_t,   bufPtr, assignTo)
#define STORE_UINT8(bufPtr,  assignTo) STORE_TYPE(uint8_t,  bufPtr, assignTo)
#define STORE_INT16(bufPtr,  assignTo) STORE_TYPE(int16_t,  bufPtr, assignTo)
#define STORE_UINT16(bufPtr, assignTo) STORE_TYPE(uint16_t, bufPtr, assignTo)
#define STORE_INT32(bufPtr,  assignTo) STORE_TYPE(int32_t,  bufPtr, assignTo)
#define STORE_UINT32(bufPtr, assignTo) STORE_TYPE(uint32_t, bufPtr, assignTo)
#define STORE_SINGLE(bufPtr, assignTo) STORE_TYPE(single_t, bufPtr, assignTo)
#define STORE_DOUBLE(bufPtr, assignTo) STORE_TYPE(double_t, bufPtr, assignTo)

// these macros help with the process of pulling nElements*sizeof(type) bytes off
// of a uint8_t buffer [bufPtr], typecasting them as [type], and storing them
// into a buffer [pAssign]. The bufPtr is automatically advanced by the correct
// number of bytes. assignTo must be of type [type*], i.e. a pointer.
#define STORE_TYPE_ARRAY(type, bufPtr, pAssign, nElements) \
    memcpy(pAssign, bufPtr, nElements*sizeof(type)); bufPtr += sizeof(type) * nElements

#define STORE_CHAR_ARRAY(   bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(char,     bufPtr, pAssign, nElements)
#define STORE_INT8_ARRAY(   bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(int8_t,   bufPtr, pAssign, nElements)
#define STORE_UINT8_ARRAY(  bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(uint8_t,  bufPtr, pAssign, nElements)
#define STORE_INT16_ARRAY(  bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(int16_t,  bufPtr, pAssign, nElements)
#define STORE_UINT16_ARRAY( bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(uint16_t, bufPtr, pAssign, nElements)
#define STORE_INT32_ARRAY(  bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(int32_t,  bufPtr, pAssign, nElements)
#define STORE_UINT32_ARRAY( bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(uint32_t, bufPtr, pAssign, nElements)
#define STORE_SINGLE_ARRAY( bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(single_t, bufPtr, pAssign, nElements)
#define STORE_DOUBLE_ARRAY( bufPtr, pAssign, nElements) STORE_TYPE_ARRAY(double_t, bufPtr, pAssign, nElements)

/////////// DATA STRUCTURES //////////////

#define BUFFER_NUM_TRIALS 3

typedef Trie GroupTrie;
typedef double timestamp_t; // timestamps in ms
typedef double wallclock_t;
typedef double datenum_t;

// group keys are just the name
#define GROUPKEYLENGTH (MAX_GROUP_NAME + 1)

// we'll keep track of trial specific info here
typedef struct DataLoggerStatusByTrial {
    // status flags
    bool activeLogging;
    bool activeWriting;
    bool utilized;
    bool completed;

    // metadata
    uint32_t trialId;
    bool autoTrialId; // determine trialId at time of first utilization

    // in case long trials are split across multiple files
    uint32_t trialPortion;

    wallclock_t wallclockStart; // wallclock time provided by this computer (sec since unix epoch)
    wallclock_t wallclockEnd; // most recently updated group

    timestamp_t timestampStart; // timestamps provided by the xpc computer (milliseconds)
    timestamp_t timestampEnd; // most recently updated group
} DataLoggerStatusByTrial;

// and collect this info here
typedef struct DataLoggerStatus {

    // waiting for next trial command to arrive in order to start writing
    bool pendingNextTrial;

    // no longer actively being written into, just waiting for data inside to be written to disk or retrieved
    // before freeing all memory
    bool retired;

    // for thread-safe buffering and access
    pthread_mutex_t mutex;
    pthread_mutexattr_t mutexAttr;

    // metadata. *Specified is false if using the default values (before the specification signal arrives)
    char dataStore[MAX_STRING];
    bool dataStoreSpecified;

    char subject[MAX_STRING];
    bool subjectSpecified;

    char protocol[MAX_STRING];
    bool protocolSpecified;

    uint32_t protocolVersion;
    bool protocolVersionSpecified;

    uint32_t saveTag;
    bool saveTagSpecified;

    unsigned currentTrial; // indexes into all arrays marked with length [BUFFER_NUM_TRIALS]
    DataLoggerStatusByTrial byTrial[BUFFER_NUM_TRIALS];
    GroupTrie* gtrie;
} DataLoggerStatus;

// timestamps are buffered inside GroupInfo (for each trial)
typedef struct TimestampBuffer {
    timestamp_t* timestamps;

    // in use
    uint32_t nSamples;

    // allocated
    uint32_t samplesAllocated;
} TimestampBuffer;

// samples are buffered inside SignalDataBuffer (for each trial)
// here a sample corresponds to a chunk of data received in one group (one packet)
// it is unaware if there are multiple timestamps within those samples
typedef struct SampleBuffer {
    uint32_t dataAllocated;
    uint8_t* data;

    // actually used samples, data bytes
    uint32_t nSamples;
    uint32_t nDataBytes;

    // how many bytes in each sample
    uint32_t* bytesEachSample;

    // have all samples so far have had same size?
    bool samplesDifferentSizes;

    // length of bytesEachSample allocated
    uint32_t samplesAllocated;
} SampleBuffer;

// pre-declare since the reference is circular below
struct SignalDataBuffer;

// stores header information about a group of signals
typedef struct GroupInfo
{
    uint16_t version; // data serializer block version
    char name[MAX_GROUP_NAME+1];
    uint8_t type; // group type, see GROUP_TYPE_* constants above

    uint32_t configHash; // 4 byte hash of group configuration to check for changes

    timestamp_t lastTimestamp; // last received timestamp

    // the signals which comprise this group
    uint16_t nSignals; // number of signals in this group
    struct SignalDataBuffer** signals;

    TimestampBuffer tsBuffers[BUFFER_NUM_TRIALS];
} GroupInfo;

// signal sample buffer plus metadata about signal
typedef struct SignalDataBuffer
{
	// sent with the signal
    bool isVariable;
    bool concatLastDim;

    uint8_t type; // one of the SIGNALTYPE_ constants above
    uint8_t concatDimension; // which dimension should this signal be concatenated along

    char name[MAX_SIGNAL_NAME+1];
    char units[MAX_SIGNAL_UNITS+1];

    uint8_t dataTypeId;

    // NOTE: THESE ARE THE DIMENSIONS OF THE FIRST INDIVIDUAL SAMPLE OF THIS SIGNAL
    // not for the concatenated whole signal, we use this for keeping track of whether samples
    // have the same size so we know whether to store in a cell or a matrix at the end.
    // To get the size of the accumulated full signal this trial, look inside ->buffers.
    uint8_t nDims;
    uint16_t dims[MAX_SIGNAL_NDIMS];

    // whether the size along each dimension is consistent across all samples, 
    // which determines whether concatenation is possible
    bool dimChangesSize[MAX_SIGNAL_NDIMS];

    // pointer back to the group info for convenience
    GroupInfo* pGroupInfo;

    // buffers for signal data, we hold several trials simultaneously and loop through them so
    // that the writer thread has time to keep up with the network-receive thread
    SampleBuffer buffers[BUFFER_NUM_TRIALS];
} SignalDataBuffer;

typedef struct SignalSample {
    // metadata about this signal, redundant with SignalDataBuffer
    bool isVariable;
    bool concatLastDim;
    uint8_t type; // one of the SIGNAL_TYPE constants above
    uint8_t concatDimension; // which dimension should this signal be concatenated along

    char name[MAX_SIGNAL_NAME+1];
    char units[MAX_SIGNAL_UNITS+1];

    uint8_t dataTypeId;
    uint8_t nDims;
    uint16_t dims[MAX_SIGNAL_NDIMS];

    GroupInfo* pGroupInfo;

    timestamp_t timestamp;
    uint32_t dataBytes;
    uint8_t* data;
} SignalSample;

////// PROTOTYPES ////////

uint8_t getSizeOfDataTypeId(uint8_t);
const char* getDataTypeIdName(uint8_t);
bool getGroupTypeName(uint8_t, char*);
bool getSignalTypeName(uint8_t, char*);

bool mallocSignalSampleData(SignalSample*);
void freeSignalSampleData(SignalSample*);

void printSignal(const SignalSample*);
void printGroupInfo(const GroupInfo*);

// Timestamp Buffer
bool ensureTimestampBufferCapacity(TimestampBuffer *, uint32_t);
bool ensureTimestampBufferAdditionalCapacity(TimestampBuffer *, uint32_t);
void clearTimestampBuffer(TimestampBuffer*);
void freeTimestampBuffer(TimestampBuffer*);
// push a single timestamp to a TimestampBuffer
bool pushTimestampToTimestampBuffer(TimestampBuffer*, timestamp_t);
bool replaceTimestampBufferData(TimestampBuffer*, timestamp_t);

// Sample Buffer
bool ensureSampleBufferCapacity(SampleBuffer *, uint32_t, uint32_t);
bool ensureSampleBufferAdditionalCapacity(SampleBuffer *, uint32_t, uint32_t);
void clearSampleBuffer(SampleBuffer*);
void freeSampleBuffer(SampleBuffer*);
bool pushSampleToSampleBuffer(SampleBuffer*, uint32_t, const uint8_t*);
bool replaceSampleBufferData(SampleBuffer*, uint32_t, const uint8_t*);

// Signal Data Buffer
bool checkSignalDataBufferMatchesSample(const SignalDataBuffer*, const SignalSample*);
SignalDataBuffer* buildSignalDataBufferFromSample(const SignalSample*);
bool pushSignalSampleToSignalDataBuffer(SignalDataBuffer*, const SignalSample*);
void freeSignalDataBuffer(SignalDataBuffer *);

// GroupInfo and GroupTrie
GroupInfo* findGroupInfoInTrie(const GroupInfo*);
GroupInfo* addGroupInfoToTrie(const GroupInfo*);
void freeGroupInfo(GroupInfo*);
void freeGroupInfoTrie(GroupTrie*);
// push a timestamp or multiple timestamps to a group, checking the signals in samples for signals
// of type SIGNAL_TYPE_TIMESTAMP or SIGNAL_TYPE_TIMESTAMPOFFSET and doing appropriate timestamp adjustments
timestamp_t pushTimestampToGroupInfo(GroupInfo*, timestamp_t, const SignalSample* samples, int nSignals);
GroupTrie* getCurrentGroupTrie();
GroupTrie* getFirstGroupNode(GroupTrie*);
GroupTrie* getNextGroupNode(GroupTrie*);
unsigned getGroupCount(GroupTrie*);
unsigned getGroupTotalSignalCount(GroupTrie* gtrie);

// Data Logger Control
void controlInitialize(bool); // initialize pendingNextTrial (true means don't log signals until NextTrial control signal is received)
void controlTerminate();

bool controlGetWaitingForNextTrial();
bool processControlSignalSamples(unsigned, const SignalSample*);
void controlInitializeStatus(DataLoggerStatus*, const DataLoggerStatus*);
void freeDataLoggerStatus(DataLoggerStatus*);
DataLoggerStatus* controlGetCurrentStatus();
DataLoggerStatusByTrial* controlGetCurrentStatusByTrial();
unsigned controlGetCurrentTrialIndex();

// data buffer maintenance
void controlManualSplitCurrentTrial();
void controlManualSplitCurrentTrialIfOlderThan(timestamp_t);
void controlFlushTrialsOlderThan(timestamp_t);
void controlClearTrialData(DataLoggerStatus* dlStatus, unsigned trialIdx);
unsigned controlManualSplitCurrentTrialMarkForWriting(DataLoggerStatus *);

// thread-synchronizing trial array operations
int controlGetNextCompleteTrialToWrite(DataLoggerStatus*);
void controlMarkTrialWritten(DataLoggerStatus*, unsigned);
void controlMarkCurrentTrialUtilized(timestamp_t);
void controlMarkTrialComplete(DataLoggerStatus*, unsigned);
void controlMarkTrialWritten(DataLoggerStatus*, unsigned);
unsigned controlAdvanceToNextTrial(uint32_t, bool);

// status retirement buffer management
DataLoggerStatus* controlAdvanceToNewStatus();
void controlPushRetiredStatus(DataLoggerStatus*);
DataLoggerStatus* controlPopRetiredStatus();
void controlFlushRetiredStatuses();

#endif // ifndef SIGNAL_H_INCLUDE
