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

UINT16_T cb_getContinuousNumChannels(cbPKT_GENERIC* pp)
{
   // dlen is number of 4 byte words, each channel has a uint16 2 byte sample
   return pp->dlen * 2;
}

void cb_copySpikeWaveform(cbPKT_GENERIC* pp, INT16_T* buffer, int maxSamples)
{
    // ps->dlen indicates the number of 4 byte words in the 
    // fPattern (3*4), nPeak(2), nValley (2 bytes), and wave fields.
    // thus we want to copy (dlen-4)*4 bytes of data
    cbPKT_SPK* ps = (cbPKT_SPK*)pp;
    if(buffer) memcpy(buffer, ps->wave, MIN(maxSamples*sizeof(INT16_T), (ps->dlen-4) * 4));
}

// this is a workaround for not being able to pass in a reference directly to a struct field,
// e.g. using coder.ref(spikeData.spikeWaveforms). It reequires the definition of SpikeDataBus*
// to live in an generated file called CerebusBuses.h, referenced by cerebusParse.h
void cb_copySpikeWaveformIntoStructFieldColumn(cbPKT_GENERIC* pp, SpikeDataBus* spikeData, 
        int numRows, int columnNumber)
{
    INT16_T* pColumnStart = &spikeData->spikeWaveforms[(columnNumber-1)*numRows];
    cb_copySpikeWaveform(pp, pColumnStart, numRows);
}

void cb_copyContinuousSamples(cbPKT_GENERIC* pp, INT16_T* buffer, int maxChannels)
{
    // ps->dlen indicates the number of 4 byte words in the data
    cbPKT_GROUP* pg = (cbPKT_GROUP*)pp;
    if(buffer) memcpy(buffer, pg->data, MIN(maxChannels*sizeof(INT16_T), pg->dlen * 4));
}
