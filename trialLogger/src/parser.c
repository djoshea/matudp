#include <stdio.h>
#include <string.h>
#include "utils.h"
#include "parser.h"

// this is the callback function called by the network thread
// to receive packet data placed into a PacketData struct
//
// process the raw data stream and parse into signals,
// push these signals to the signal buffer
// returns true if parsing successful
void processReceivedPacketData(const PacketData * pRaw)
{
    GroupInfo g;
    GroupInfo* pgOnTrie;
    const uint8_t* pBufStart = pRaw->data;
    const uint8_t* pBuf = pRaw->data;
    bool isControlGroup, firstTimeGroupSeen, success, waitingNextTrial;
    int iSignal, nSignals;

//    logInfo("processing raw data!");

    while(pBuf - pBufStart < pRaw->length) {

        if(*pBuf == 0) {
            // consider this the null terminator
            // odd-length packets are expanded to be even length in Simulink
            // so this can occasionally happen
            break;
        }

        // parse the group header and build out the GroupInfo g
        pBuf = parseGroupInfoHeader(pBuf, &g);
        if(pBuf == NULL) {
        	logError("Could not parse group header\n");
        	return;
        }

        nSignals = g.nSignals;

        if(nSignals == 0 || nSignals > MAX_GROUP_SIGNALS) {
            logError("Group %s has too many signals (%d)\n", g.name, nSignals);
            return;
        }

        // can do different processing here depending on the version of the packet

        // handle control groups differently
        if(g.type == GROUP_TYPE_CONTROL)
            isControlGroup = true;
        else
            isControlGroup = false;

        // allocate space to parse and hold onto all the signals at once
        // we do this in one pass in case parsing fails, since then we'll need to bail
        SignalSample* samples = (SignalSample*)CALLOC(sizeof(SignalSample), nSignals);

        // parse all the signals into SignalSamples
        bool parseError = false;
        for(iSignal = 0; iSignal < nSignals; iSignal++) {
            pBuf = parseSignalFromBuffer(pBuf, samples + iSignal);
            samples[iSignal].timestamp = g.lastTimestamp;

            if(pBuf == NULL) {
            	parseError = true;
                logError("Error parsing signal %d / %d from buffer for group %s\n", iSignal+1, nSignals, g.name);
                for(; iSignal >= 0; iSignal--)
                    freeSignalSampleData(samples + iSignal);
                FREE(samples);
                return;
            }
        }

        if(parseError) {
            for(iSignal = 0; iSignal < nSignals; iSignal++)
                freeSignalSampleData(samples + iSignal);
            FREE(samples);
            return;
        }

        if(isControlGroup) {

            success = processControlSignalSamples(nSignals, (const SignalSample*)samples);
            if(!success) {
                logError("Issue handling control signals\n");
                for(iSignal = 0; iSignal < nSignals; iSignal++)
                    freeSignalSampleData(samples + iSignal);
                FREE(samples);
                return;
            }

        } else {

            // non control group

            // check whether we'll store this or not
            waitingNextTrial = controlGetWaitingForNextTrial();

            if(!waitingNextTrial) {
                firstTimeGroupSeen = false;
                // find existing group info onto the group trie
                // and hold onto that pointer
                pgOnTrie = findGroupInfoInTrie(&g);
                if(pgOnTrie == NULL) {
                    firstTimeGroupSeen = true;
                    // build a new group info on the group trie
                    // this will also allocate the signals pointer list to be length nSignals
                    pgOnTrie = addGroupInfoToTrie(&g);
                }

                // check the hash matches, bail if not
                if(pgOnTrie->configHash != g.configHash || pgOnTrie->nSignals != nSignals) {
                    logError("Group %s received with different configuration\n", pgOnTrie->name);

                    // free memory and bail
                    for(iSignal = 0; iSignal < nSignals; iSignal++)
                        freeSignalSampleData(samples + iSignal);
                    FREE(samples);

                    controlAdvanceToNewStatus();
                    return;
                }

                // associate each sample with this group
                for(iSignal = 0; iSignal < nSignals; iSignal++)
                    samples[iSignal].pGroupInfo = pgOnTrie;

                // if it's the first time we've seen this group, build a SignalDataBuffer for each signal
                if(firstTimeGroupSeen) {
                    for(iSignal = 0; iSignal < nSignals; iSignal++) {
                        pgOnTrie->signals[iSignal] = buildSignalDataBufferFromSample(samples + iSignal);

                        if(pgOnTrie->signals == NULL) {
                            logError("Error building signal data buffer\n");
                            for(iSignal = 0; iSignal < nSignals; iSignal++)
                                freeSignalSampleData(samples + iSignal);
                            FREE(samples);
                            return;
                        }
                    }
                }

                // add the timestamp to the group info, this is also where adjust the timestamps
                // for this sample based on signals with SIGNAL_TYPE_TIMESTAMP AND SIGNAL_TYPE_TIMESTAMPOFFSET
                // update the pgOnTrie's last timestamp with the last corrected timestamp as well
                pgOnTrie->lastTimestamp = pushTimestampToGroupInfo(pgOnTrie, g.lastTimestamp, (const SignalSample*)samples, nSignals);

                // and push each signal sample to each signal data buffer
                for(iSignal = 0; iSignal < nSignals; iSignal++) {
                    success = pushSignalSampleToSignalDataBuffer(pgOnTrie->signals[iSignal], samples + iSignal);
                    if(!success) {
                        logError("Issue pushing signal data sample\n");
                        for(iSignal = 0; iSignal < nSignals; iSignal++)
                            freeSignalSampleData(samples + iSignal);
                        FREE(samples);
                        return;
                    }
                }
            }
        }

        // free data used by the SignalSamples
        for(iSignal = 0; iSignal < nSignals; iSignal++)
            freeSignalSampleData(samples + iSignal);
        FREE(samples);
        samples = NULL;

        // done parsing group, loop to next part of buffer
    }
}

// parses a single signal sample off the bytestream buffer and stores the information
// and data in ps
//
// if parsing fails, returns NULL
// if parsing successful, returns a pointer to the next unread byte in the buffer
const uint8_t * parseSignalFromBuffer(const uint8_t * buffer, SignalSample* ps)
{
    const uint8_t* pBuf = buffer;

    // clear the signal sample
    memset(ps, 0, sizeof(SignalSample));

    // parse the bit flags
    uint8_t bitFlags;
    STORE_UINT8(pBuf, bitFlags);
    if(bitFlags & 1)
        ps->isVariable = true;
    else
        ps->isVariable = false;
    if(bitFlags & 2)
    	ps->concatLastDim = true;
    else
    	ps->concatLastDim = false;

    // signal type
    STORE_UINT8(pBuf, ps->type);

    // get the number of bytes in the signal name
    uint16_t lenName;
    STORE_UINT16(pBuf, lenName);

    if(lenName == 0 || lenName  > MAX_SIGNAL_NAME) {
        logParsingError("Signal name too long (%d)\n", lenName);
		return NULL;
    }

    // store the signal name
    STORE_UINT8_ARRAY(pBuf, ps->name, lenName);

    // get the number of bytes in the signal units
    uint16_t lenUnits;
    STORE_UINT16(pBuf, lenUnits);

    if(lenUnits > MAX_SIGNAL_UNITS) {
        logParsingError("Signal units too long (%d)\n", lenUnits);
        return NULL;
    }

    if(lenUnits > 0) {
    	// store the signal name
    	STORE_UINT8_ARRAY(pBuf, ps->units, lenUnits);
    } else {
    	strcpy(ps->units, "");
    }

    // store the data type
    STORE_UINT8(pBuf, ps->dataTypeId);

    // store the number of dimensions
    STORE_UINT8(pBuf, ps->nDims);
    if(ps->nDims > MAX_SIGNAL_NDIMS || ps->nDims == 0) {
        logParsingError("Signal '%s' dimension count invalid (%d)!\n",
                ps->name, ps->nDims);
        return NULL;
    }

    // store the size along each dimension
    STORE_UINT16_ARRAY(pBuf, ps->dims, ps->nDims);

    // compute the number of bytes in the data
    unsigned nElements = 1;
    for(int idim = 0; idim < ps->nDims; idim++) {
        if(ps->dims[idim] > MAX_SIGNAL_SIZE) {
            logParsingError("Signal dimension %d invalid (%d)!\n",
                    idim, ps->dims[idim]);
            return NULL;
        }
        nElements *= ps->dims[idim];
    }

    // read the data as uint8, we'll typecast later
    unsigned dataBytesBuffer = nElements * getSizeOfDataTypeId(ps->dataTypeId);

    // figure out how many bytes we want for storage too, may be different
    // to allow trailing terminators
    ps->dataBytes = dataBytesBuffer;
    if (ps->dataTypeId == DTID_CHAR) {
        // leave an extra character for the trailing terminator
        ps->dataBytes++;
    }

    // allocate space for the signal data, leave room for trailing terminator
    bool success = mallocSignalSampleData(ps);
    if(!success)
        return NULL;

    // and store the signal data
    STORE_UINT8_ARRAY(pBuf, ps->data, dataBytesBuffer);

    return pBuf;
}

// given the bytestream buffer, read the next few bytes of buffer which
// are expected to constitute a serialized group info header, store the group info in pg,
// and return the advanced pointer into the buffer (i.e. to the next unread character)
//
// if group header parsing fails, returns NULL
//
// this will need to match +BusSerialize/serializeDataLoggerHeader.m
const uint8_t * parseGroupInfoHeader(const uint8_t * buffer, GroupInfo *pg)
{
    const uint8_t *pBuf = buffer;
    uint16_t nChars = 0;

    // clear the group info
    memset(pg, 0, sizeof(GroupInfo));

    // group version
    STORE_UINT8(pBuf, pg->version);

    // group type code
    STORE_UINT8(pBuf, pg->type);

    // config hash
    STORE_UINT32(pBuf, pg->configHash);

    // number of signals
    STORE_UINT16(pBuf, pg->nSignals);

    // group name
    STORE_UINT16(pBuf, nChars);
    if(nChars == 0 || nChars > MAX_SIGNAL_NAME) {
        logParsingError("Group name invalid length (%d)\n", nChars);
        return NULL;
    }
    STORE_UINT8_ARRAY(pBuf, pg->name, nChars);

    // timestamp for this sample in the header (this may be overwritten later)
    uint32_t lastTimestamp;
    STORE_UINT32(pBuf, lastTimestamp);
    pg->lastTimestamp = (timestamp_t)lastTimestamp;

    return pBuf;
}
