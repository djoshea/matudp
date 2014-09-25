// see build_udpMexReceiver for mex build call
// Authors: Dan O'Shea, Vikash Gilja
//
// This class binds to a UDP socket and receives data in a particular format.
// Packets arrive and are identified as members of PacketSets, which are a way of
// splitting large data across multiple packets. Once the entire PacketSet has arrived,
// it is parsed into Groups of Signals, where Signals are named, typed Matlab variables.
// Network I/O, parsing, and grouping all occur asynchronously in a background thread.
// When the mex function is called, any groups on the buffer are converted into mxArrays
// and returned to Matlab, which happens very quickly.
//
// Raw bytes may also be sent through the UDP port as well.
//

// Windows Instructions:
//      For mex compilation: mex -lrt udpFileWriter.cpp -Ic:\users\gilja\desktop\Pre-built.2\include ws2_32.lib -lpthreadVC2 -Lc:\users\gilja\desktop\Pre-built.2\lib\x64\ -DWIN32
//      To run and compile we need the win32-pthread library, specifically pthreadVC2 if we're using Visual Studio to compile.  To run, we copy the DLL to c:\windows\system32

#include "math.h"
#include "mex.h"   //--This one is required

#include <string.h>
#include <pthread.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <ctype.h>
#include <unistd.h>
#include <time.h>

// DATA LOGGER PARSING HEADERS
#include "../serializedDataLogger/src/utils.h"
#include "../serializedDataLogger/src/signal.h"
#include "../serializedDataLogger/src/writer.h"
#include "../serializedDataLogger/src/parser.h"
#include "../serializedDataLogger/src/network.h"

///////////// GLOBALS /////////////

pthread_t dataFlushThread;
int mex_call_counter = 0;

// PRIVATE DECLARATIONS
bool startServer();
void stopServer();
void cleanupAtExit();
int strcmpi(const char *,const char *);
unsigned convertInputArgsToBytestream(uint8_t*, unsigned, int, const mxArray **);

void dataFlushThreadStart();
void dataFlushThreadTerminate();
void * dataFlushThreadWorker(void *);

NetworkAddress recv;
NetworkAddress send;

// LOCAL DEFINITIONS
void cleanupAtExit() {
    stopServer();
}

bool startServer() {
    char errMsg[MAX_HOST_LENGTH + 50];
    bool success = false;

    logInfo("Starting server...\n");
    mexLock();

    // initialize signal processing buffers and group lookup trie
    // true means wait until next trial is received to start buffering
    // false means start buffering immediately, even if next trial hasn't been received
    controlInitialize(true);

    // install the callback function for received packet data
    networkSetPacketReceivedCallbackFn(&processReceivedPacketData);

    success = networkReceiveThreadStart(&recv) == 0;

    if(!success) {
        controlTerminate();
        mexUnlock();
        snprintf(errMsg, MAX_HOST_LENGTH + 50, "Could not start network receiver at %s",
                getNetworkAddressAsString(&recv));
        mexErrMsgTxt(errMsg);
        return false;
    }

    networkOpenSendSocket();
    //dataFlushThreadStart();
    return true;
}

void stopServer()
{
    logInfo("Stopping server!\n");
    //dataFlushThreadTerminate();
    networkReceiveThreadTerminate();
    networkCloseSendSocket();
    controlTerminate();
}

int strcmpi(const char *s1,const char *s2)
{
    int val;
    while( (val= toupper(*s1) - toupper(*s2))==0 ){
        if(*s1==0 || *s2==0) return 0;
        s1++;
        s2++;
        //while(*s1=='_') s1++;
        //while(*s2=='_') s2++;
    }
    return val;
}

void* p;

void mexFunction(
        int           nlhs,           /* number of expected outputs */
        mxArray       *plhs[],        /* array of pointers to output arguments */
        int           nrhs,           /* number of inputs */
        const mxArray *prhs[]         /* array of pointers to input arguments */
        )
{
    //char * validCommands[] = {"start", "stop", "retrieveGroups", "pollGroups"};
    //unsigned nValidCommands = 4;

    char fun[80+1];
    char tempAddressString[MAX_HOST_LENGTH];
    double tempPort;
    bool success = false;

    uint8_t sendBuffer[MAX_PACKET_LENGTH];
    size_t totalBytesSend;

    // register cleanup function
    mexAtExit(cleanupAtExit);

    if(mex_call_counter==0)
    {
        // first call
        mex_call_counter++;
    }

    //mexPrintf("UdpMex: sleeping a bit\n");
    /*
    struct timespec req;
    req.tv_sec = 0;
    req.tv_nsec = 10000000; // sleep for 10 ms
    nanosleep(&req, &req);
    */

    if((nrhs >= 1) && mxIsChar(prhs[0])) {
        // GET FIRST ARGUMENT -- The "function" name
        mxGetString(prhs[0],fun,80);

        if(strcmpi(fun, "start")==0) {
            if(mexIsLocked()) {
                mexErrMsgTxt("UdpMex: already started");
                return;
            }

            if(nrhs != 3) {
                mexErrMsgTxt("UdpMex: usage: udpMexReceiver('start', receiveIPAndPort, sendIPAndPort)");
                return;
            }

            // parse receive ip address
            success = false;
            if(mxIsChar(prhs[1])) {
                mxGetString(prhs[1], tempAddressString, MAX_HOST_LENGTH);
                success = parseNetworkAddress(tempAddressString, &recv);

            } else if(mxIsNumeric(prhs[1])) {
                // parse directly as port number
                tempPort = mxGetScalar(prhs[1]);
                snprintf(tempAddressString, MAX_HOST_LENGTH, "%d", (int)floor(tempPort));
                setNetworkAddress(&recv, "", "", tempPort);
                success = true;
            }
            if(!success) {
                mexErrMsgTxt("UdpMex: receiveIPAndPort must be 'ip:port' or numeric port");
                return;
            }

            // parse receive ip address
            success = false;
            if(mxIsChar(prhs[2])) {
                mxGetString(prhs[2], tempAddressString, MAX_HOST_LENGTH);
                success = parseNetworkAddress(tempAddressString, &send);

            } else if(mxIsNumeric(prhs[2])) {
                // parse directly as port number with no interface or host
                tempPort = mxGetScalar(prhs[2]);
                snprintf(tempAddressString, MAX_HOST_LENGTH, "%d", (int)floor(tempPort));
                setNetworkAddress(&send, "", "", tempPort);
                success = true;
            }
            if(!success) {
                mexErrMsgTxt("UdpMex: sendIPAndPort must be 'interface:host:port', 'host:port', numeric port");
                return;
            }

            // bind socket
            mexPrintf("UdpMex: Starting server at %s\n", getNetworkAddressAsString(&recv));
            success = startServer();
            if(!success)
                mexUnlock();

            return;

        } else if(strcmpi(fun,"stop")==0) {
            if (mexIsLocked()) {
                mexPrintf("UdpMex: stopping\n");
                stopServer();
                mexUnlock();

                return;
            } else {
                mexPrintf("UdpMex: already stopped\n");
            }

        } else if(strcmpi(fun, "send") == 0) {
            if(!mexIsLocked()) {
                mexErrMsgTxt("UdpMex: call with 'start' to bind socket first.");
                return;
            }

            // send data back, prepended with prefix, then
            // loop through input arguments and byte pack them
            if(nrhs < 2) {
                mexErrMsgTxt("UdpMex: call with subsequent arguments to send");
                return;
            }

            // convert input arguments to bytes to send
            totalBytesSend = convertInputArgsToBytestream(sendBuffer, MAX_PACKET_LENGTH, nrhs, prhs);

            if(totalBytesSend == -1) {
                mexErrMsgTxt("UdpMex: Cannot fit data into one packet!");
                return;
            }

            if(!networkSend((char*)sendBuffer, totalBytesSend)) {
                mexErrMsgTxt("UdpMex: Sendto error");
                return;
            }

        } else if(strcmpi(fun,"retrieveGroups")==0) {
            if(!mexIsLocked()) {
                mexErrMsgTxt("UdpMex: call with 'start' to bind socket first.");
                return;
            }

            // retrieve groups(i) array from current trial, flush data
            if(nlhs != 1) {
                mexErrMsgTxt("UdpMex: no output arguments");
                return;
            }

            // send groups on buffer out
            plhs[0] = buildGroupsArrayForCurrentTrial(true);

        } else if(strcmpi(fun, "pollGroups")==0) {
            if(!mexIsLocked()) {
                mexErrMsgTxt("UdpMex: call with 'start' to bind socket first.");
                return;
            }

            if(nlhs != 1) {
                mexErrMsgTxt("UdpMex: no output arguments");
                return;
            }

            // send groups on buffer out
            plhs[0] = buildGroupsArrayForCurrentTrial(false);

        } else if(strcmpi(fun, "retrieveCompleteTrial")==0) {
            if(!mexIsLocked()) {
                mexErrMsgTxt("UdpMex: call with 'start' to bind socket first.");
                return;
            }

            if(nlhs != 2) {
                mexErrMsgTxt("UdpMex: two outputs required: [trial, meta]");
                return;
            }

            // send groups on buffer out
            buildTrialStructForLastCompleteTrial(&(plhs[0]), &(plhs[1]));

        } else if(strcmpi(fun, "pollCurrentTrial")==0) {
            if(!mexIsLocked()) {
                mexErrMsgTxt("UdpMex: call with 'start' to bind socket first.");
                return;
            }

            if(nlhs != 2) {
                mexErrMsgTxt("UdpMex: two outputs required: [trial, meta]");
                return;
            }

            // send groups on buffer out
            buildTrialStructForCurrentTrial(&(plhs[0]), &(plhs[1]));

        } else {
            mexErrMsgTxt("UdpMex: invalid syntax!");
            return;
        }
    } else {
        mexErrMsgTxt("UdpMex: please call with command argument ('start', 'stop', 'pollGroups', 'receiveGroups')");
    }

    return;
}

unsigned convertInputArgsToBytestream(uint8_t* buffer, unsigned sizebuf, int nrhs, const mxArray ** prhs) {
    uint8_t* pSendBufferWrite;
    unsigned bytesThisArg;

    memset(buffer, 0, sizebuf);
    pSendBufferWrite = buffer;

    // then loop through args and bytepack
    for(int iArg = 1; iArg < nrhs; iArg++) {
        // check for buffer overrun
        if(pSendBufferWrite > buffer + sizebuf)
            return -1;

        if (mxIsChar(prhs[iArg]))
            bytesThisArg = mxGetNumberOfElements(prhs[iArg]);
        else
            bytesThisArg = mxGetElementSize(prhs[iArg])*mxGetNumberOfElements(prhs[iArg]);

        if(pSendBufferWrite + bytesThisArg >= buffer + MAX_PACKET_LENGTH - 1) {
            mexErrMsgTxt("Data too large to fit into a packet");
            return -1;
        }

        if (mxIsChar(prhs[iArg])) {
            // copy string directly as ASCII since char in Matlab is actually 2-byte unicode (UTF-16?)
            mxGetString(prhs[iArg], (char*)pSendBufferWrite,
                buffer + MAX_PACKET_LENGTH - pSendBufferWrite - 2);
        } else {
            memcpy(pSendBufferWrite, mxGetData(prhs[iArg]), bytesThisArg);
        }

        pSendBufferWrite += bytesThisArg;
    }

    return pSendBufferWrite - buffer;
}

void dataFlushThreadStart() {
    // Start Network Receive Thread
    int rc = pthread_create(&dataFlushThread, NULL, dataFlushThreadWorker, NULL);
    if (rc) {
        logError("ERROR! Return code from pthread_create() is %d\n", rc);
        exit(-1);
    }
}

void dataFlushThreadTerminate() {
    pthread_cancel(dataFlushThread);
    pthread_join(dataFlushThread, NULL);
}

void * dataFlushThreadWorker(void * dummy)
{
    unsigned nSecondsExpire = 10;
    struct timespec req;
    pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);

    while(1)
    {
        //logInfo("Cleaning old data\n");
        // flush retired data logger statuses
        controlFlushRetiredStatuses();

        // split the current trial into pieces if older than some threshold
        controlManualSplitCurrentTrialIfOlderThan(nSecondsExpire);

        // flush trials whose data are all older than some threshold
        controlFlushTrialsOlderThan(2*nSecondsExpire);

        // wait
        pthread_testcancel();
        req.tv_sec = 1;
        req.tv_nsec = 0;
        nanosleep(&req, &req);
    }

    return NULL;
}

