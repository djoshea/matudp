#include <stddef.h>
#include <stdlib.h>
#include "simstruc.h"

#ifndef MATLAB_MEX_FILE
#include <windows.h>
#include "xpctarget.h"
#endif

#ifdef MATLAB_MEX_FILE
#include "mex.h"
#endif

#include "nblib.h"
#include "utilities.c"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cerebusParse.h"
#include "nblib.h"

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))

/// xPC Networking utilities
// 
// // returns NULL on error
// cbPKT_GENERIC* cb_nbExtractPacketData(UINT32_T* nbInput, UINT32_T* pDataLen) {
//    // Get Buffer
//    xpcNBError error;
//    xpcNB* nb = (xpcNB*)nbInput;
//    INT32_T len;
//    cbPKT_GENERIC* pp;
// 
//    // Accept Buffer
//    if ( error = xpcNBAccept(nb) ) 
//    {
//       fprintf(stderr, "CerebusParse: Network Buffer Extract Accept Error %d", error);
//       return NULL;
//    }
// 
//    len = xpcNBBytes(nb);
//    if ( len < 0 ) len = 0;
// 
//    pp = (cbPKT_GENERIC*)xpcNBData(nb);
//    *pDataLen = len;
//    
//    return pp;
// }
// 
// // returns true on error
// bool cb_nbFree(UINT32_T* nbInput)
// {
//     xpcNB* nb = (xpcNB*)nbInput;
//     xpcNBError error;
//     // Free Buffer
//     if ( error = xpcNBFree(nb) ) {
//        fprintf(stderr, "CerebusParse: Network Buffer Extract Free Error %d", error);
//        return true;
//     }
//     return false;
// }

cbPKT_GENERIC* cb_getPointer(cbPKT_GENERIC* pp)
{
    return pp;
}

// return a pointer to the last byte in the buffer
UINT8_T* cb_getPointerToBufferEnd(cbPKT_GENERIC* pp, UINT32_T nBytes)
{
    return (UINT8_T*) (((UINT8_T*)pp) + (nBytes - 1));
}

// using the pointer to the last byte of the buffer, determine whether there
// is room for another cbPKT in the buffer. If not, return NULL. If there is
// return the pointer to the next packet
bool cb_hasNext(cbPKT_GENERIC*pp, UINT8_T* pBufferEnd)
{
    cbPKT_GENERIC* pNext = cb_getNext(pp);
    if((UINT8_T*)pNext >= pBufferEnd)
        return false;
    if(pNext->time == 0)
        return false;
    return true;
}   

cbPKT_GENERIC* cb_getNext(cbPKT_GENERIC*pp)
{
    return (cbPKT_GENERIC*)(((UINT8_T*)pp) + cbPKT_HEADER_SIZE + pp->dlen*4);
}

UINT32_T cb_getTime(cbPKT_GENERIC* pp)
{
    return pp->time;
}

UINT16_T cb_getChannel(cbPKT_GENERIC* pp)
{
    return pp->chid;
}

UINT8_T cb_getSpikeUnit(cbPKT_GENERIC* pp)
{
    return ((cbPKT_SPK*)pp)->unit;
}

bool cb_isSpikePacket(cbPKT_GENERIC* pp)
{
   return pp->chid > 0 && pp->chid <= cbNUM_ANALOG_CHANS;
}

bool cb_isContinuousPacketForGroup(cbPKT_GENERIC* pp, UINT8_T group)
{
   return pp->chid == 0 && pp->type == group;
}

UINT8_T cb_getContinuousGroup(cbPKT_GENERIC* pp) 
{
    return pp->type;
}

void cb_copySpikeWaveform(cbPKT_GENERIC* pp, INT16_T* buffer, int maxSamples)
{
    // ps->dlen indicates the number of 4 byte words in the 
    // fPattern (3*4), nPeak(2), nValley (2 bytes), and wave fields.
    // thus we want to copy (dlen-4)*4 bytes of data
    cbPKT_SPK* ps = (cbPKT_SPK*)pp;
    memcpy(buffer, ps->wave, MIN(maxSamples*sizeof(INT16_T), (ps->dlen-4) * 4));
}

void cb_copyContinuousSamples(cbPKT_GENERIC* pp, INT16_T* buffer, int maxChannels)
{
    // ps->dlen indicates the number of 4 byte words in the data
    cbPKT_GROUP* pg = (cbPKT_GROUP*)pp;
    memcpy(buffer, pg->data, MIN(maxChannels*sizeof(INT16_T), pg->dlen * 4));
}
